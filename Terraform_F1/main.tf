terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# Credenciales de la aplicacion terraform-f1-65743264 (service principal).
# Reemplazar cada marcador entre corchetes por el valor copiado del portal de Azure:
#   SUBSCRIPTION_ID = Id. de suscripcion (Suscripciones > Azure for Students)
#   CLIENT_ID       = Id. de aplicacion (Entra ID > Registros de aplicaciones)
#   CLIENT_SECRET   = Valor del secreto (Certificados y secretos)
#   TENANT_ID       = Id. de inquilino (Microsoft Entra ID > Informacion general)
# En el informe y en el repositorio publico el secreto va siempre como marcador.
provider "azurerm" {
  features {}
  subscription_id = "08cd197c-4f02-4190-8ef1-9d49240e5105"
  client_id       = "637efd10-b797-4739-9b84-5f6ecd5dbf4d"
  client_secret   = "Cp_8Q~OBr-.rBUu7kLT.d_QSeKa1BcHXcyO7sdh9"
  tenant_id       = "cc28633f-12b8-46cb-bc15-951dae239b4d"
}

locals {
  sufijo        = "65743264"
  location_main = "brazilsouth"  # Grupo de recursos y Storage (region permitida por la directiva)
  location_adf  = "brazilsouth"  # Data Factory (region permitida por la directiva)
  location_sql  = "spaincentral" # Azure SQL (brazilsouth bloquea crear servidores SQL en Azure for Students)

  # Incrementar conscientemente para recargar el DW: los scripts eliminan y recrean tablas.
  dw_seed_version = "1"

  # Los 14 CSV del dataset van a RAW; a Bronze solo se cargan los 10 necesarios (Data Factory).
  raw_files = fileset(path.module, "datos_csv/*.csv")

  dw_sql_scripts = [
    "01_bronze.sql",
    "02_silver.sql",
    "03_cuarentena.sql",
    "04_gold.sql",
  ]
}

# 1. Grupo de recursos.
resource "azurerm_resource_group" "rg" {
  name     = "gr-ucb-formula1-${local.sufijo}"
  location = local.location_main
}

# 2. Data Lake Gen2 (RAW). 15 caracteres: dentro del maximo de 24.
resource "azurerm_storage_account" "storage" {
  name                            = "saucbf1${local.sufijo}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true
  allow_nested_items_to_be_public = true
  min_tls_version                 = "TLS1_2"
}

# Contenedor RAW: datos originales sin modificar.
resource "azurerm_storage_container" "raw" {
  name                  = "raw"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "blob"
}

# Contenedor de salida para la exportacion de Gold a CSV (Fase 2).
resource "azurerm_storage_container" "gold_export" {
  name                  = "gold-export"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# Sube los 14 CSV a raw/datos_csv. lap_times.csv (17,6 MB) es el archivo mas grande:
# el hash MD5 evita volver a subirlo si no cambia.
resource "azurerm_storage_blob" "raw_files" {
  for_each = local.raw_files

  name                   = each.value
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.raw.name
  type                   = "Block"
  source                 = "${path.module}/${each.value}"
  content_md5            = filemd5("${path.module}/${each.value}")
  content_type           = "text/csv"
}

# 3. Servidor Azure SQL (en spaincentral: es la region permitida donde la suscripcion deja crear SQL).
resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-ucb-server-f1-${local.sufijo}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = local.location_sql
  version                      = "12.0"
  administrator_login          = "camilo"
  administrator_login_password = "Formula165743264!"
  minimum_tls_version          = "1.2"
}

# Acceso desde cualquier IPv4, para sqlcmd local y el Editor de consultas.
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Habilita explicitamente la conexion desde servicios alojados en Azure (Data Factory).
resource "azurerm_mssql_firewall_rule" "allow_azure_services_explicit" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Base serverless con pausa automatica.
resource "azurerm_mssql_database" "db" {
  for_each = toset(["dw_formula_1"])

  name                        = each.value
  server_id                   = azurerm_mssql_server.sql_server.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  sku_name                    = "GP_S_Gen5_1"
  max_size_gb                 = 32
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60
  storage_account_type        = "Local"
}

# 4. Carga inicial del DW: esquemas y tablas de bronze, silver, cuarentena y gold.
# Los scripts eliminan tablas existentes (bronze y silver). Para repetir la carga,
# incrementar dw_seed_version conscientemente antes de ejecutar terraform apply.
resource "terraform_data" "dw_schema" {
  triggers_replace = [
    azurerm_mssql_database.db["dw_formula_1"].id,
    local.dw_seed_version,
  ]

  depends_on = [
    azurerm_mssql_firewall_rule.allow_azure_services,
  ]

  lifecycle {
    precondition {
      condition     = alltrue([for script in local.dw_sql_scripts : fileexists("${path.module}/sql/${script}")])
      error_message = "Deben existir los cuatro scripts SQL de carga DW en sql/."
    }
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-Command"]

    environment = {
      SQL_SERVER      = azurerm_mssql_server.sql_server.fully_qualified_domain_name
      SQL_DATABASE    = azurerm_mssql_database.db["dw_formula_1"].name
      SQL_USER        = azurerm_mssql_server.sql_server.administrator_login
      SQLCMDPASSWORD  = azurerm_mssql_server.sql_server.administrator_login_password
      SQL_SCRIPT_DIR  = abspath("${path.module}/sql")
      SQL_SCRIPT_LIST = join(";", local.dw_sql_scripts)
    }

    command = <<-POWERSHELL
      $ErrorActionPreference = "Stop"
      $sqlcmdCommand = Get-Command sqlcmd -ErrorAction SilentlyContinue | Select-Object -First 1
      $sqlcmd = if ($sqlcmdCommand) { $sqlcmdCommand.Source } elseif (Test-Path -LiteralPath "C:\Program Files\SqlCmd\sqlcmd.exe") { "C:\Program Files\SqlCmd\sqlcmd.exe" } else { throw "Instale sqlcmd antes de ejecutar Terraform." }
      $commonArgs = @("-S", $env:SQL_SERVER, "-d", $env:SQL_DATABASE, "-U", $env:SQL_USER, "-b", "-r", "1", "-l", "30")

      $connected = $false
      for ($attempt = 1; $attempt -le 12; $attempt++) {
        & $sqlcmd @commonArgs -Q "SET NOCOUNT ON; SELECT 1;" *> $null
        if ($LASTEXITCODE -eq 0) {
          $connected = $true
          break
        }
        Start-Sleep -Seconds 10
      }
      if (-not $connected) {
        throw "No se pudo conectar a la base DW despues de crearla y configurar el firewall."
      }

      foreach ($scriptName in $env:SQL_SCRIPT_LIST.Split(";")) {
        $scriptPath = Join-Path $env:SQL_SCRIPT_DIR $scriptName
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
          throw "No existe el script SQL: $scriptPath"
        }
        Write-Host "Ejecutando $scriptName en $env:SQL_DATABASE"
        & $sqlcmd @commonArgs -i $scriptPath
        if ($LASTEXITCODE -ne 0) {
          throw "Fallo $scriptName (codigo $LASTEXITCODE)."
        }
      }
    POWERSHELL
  }
}

# 5. Factoria de integracion en Brazil South.
resource "azurerm_data_factory" "adf" {
  name                = "adf-ucb-f1-br-${local.sufijo}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location_adf
}

# Salidas para documentar los nombres creados.
output "grupo_de_recursos" {
  value = azurerm_resource_group.rg.name
}

output "cuenta_de_almacenamiento" {
  value = azurerm_storage_account.storage.name
}

output "servidor_sql" {
  value = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "base_de_datos" {
  value = azurerm_mssql_database.db["dw_formula_1"].name
}

output "data_factory" {
  value = azurerm_data_factory.adf.name
}

output "archivos_en_raw" {
  value = length(azurerm_storage_blob.raw_files)
}