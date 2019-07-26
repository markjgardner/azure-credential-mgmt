variable "username" {
  description = "executing users UPN"
}

provider azurerm {}

provider "azuread" {}

data "azurerm_client_config" "current" {}

data "azuread_user" "user" {
  user_principal_name = var.username
}

resource "azurerm_resource_group" "rg" {
  name     = "secureapp-rg"
  location = "eastus"
}

resource "azurerm_key_vault" "vault" {
  name                = "secureappvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azuread_user.user.id

    secret_permissions = [
      "list",
      "set",
      "get",
      "delete",
    ]
  }
}

resource "azurerm_key_vault_secret" "secret_id" {
  name         = "servicePrincipalId"
  value        = azuread_service_principal.principal.id
  key_vault_id = azurerm_key_vault.vault.id
}


resource "azurerm_key_vault_secret" "secret_pass" {
  name         = "servicePrincipalPassword"
  value        = uuid()
  key_vault_id = azurerm_key_vault.vault.id

  lifecycle {
    ignore_changes = [
      "value"
    ]
  }
}

resource "azuread_application" "app" {
  name                       = "secureapp"
  homepage                   = "https://localhost"
  identifier_uris            = ["https://myuniqueurl"]
  reply_urls                 = ["https://localhost"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "principal" {
  application_id = azuread_application.app.id
}

resource "azuread_service_principal_password" "credential" {
  service_principal_id = azuread_service_principal.principal.id
  value                = azurerm_key_vault_secret.secret_pass.value
  end_date             = timeadd(timestamp(), "21424h")

  lifecycle {
    ignore_changes = [
      "end_date"
    ]
  }
}