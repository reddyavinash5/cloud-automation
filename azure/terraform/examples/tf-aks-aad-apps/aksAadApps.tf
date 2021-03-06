# Base taken from here:
# https://github.com/dbourcet/aks-rbac-azure-ad
# https://github.com/terraform-providers/terraform-provider-azuread/issues/104#issuecomment-501593422

resource "azuread_application" "aadAppAksServer" {
  name                    = "${local.spNamePrefix}-${var.subscriptionCommonName}-${var.environmentShort}-${var.commonName}-aksserver"
  reply_urls              = ["http://${local.spNamePrefix}-${var.environmentShort}-${var.commonName}-aksserver"]
  type                    = "webapp/api"
  group_membership_claims = "All"

  required_resource_access {
    # Windows Azure Active Directory API
    resource_app_id = "00000002-0000-0000-c000-000000000000"

    resource_access {
      # DELEGATED PERMISSIONS: "Sign in and read user profile":
      # 311a71cc-e848-46a1-bdf8-97ff7156d8e6
      id   = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
      type = "Scope"
    }
  }

  required_resource_access {
    # MicrosoftGraph API
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    # APPLICATION PERMISSIONS: "Read directory data":
    # 7ab1d382-f21e-4acd-a863-ba3e13f7da61
    resource_access {
      id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
      type = "Role"
    }

    # DELEGATED PERMISSIONS: "Sign in and read user profile":
    # e1fe6dd8-ba31-4d61-89e7-88639da4683d
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }

    # DELEGATED PERMISSIONS: "Read directory data":
    # 06da0dbc-49e2-44d2-8312-53f166ab848a
    resource_access {
      id   = "06da0dbc-49e2-44d2-8312-53f166ab848a"
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "aadAppAksServer" {
  application_id = azuread_application.aadAppAksServer.application_id
}

resource "azuread_application_password" "aadAppAksServer" {
  application_object_id = azuread_application.aadAppAksServer.id
  value                 = random_password.application_server_password.result
  end_date              = timeadd(timestamp(), "87600h") # 10 years

  lifecycle {
    ignore_changes = [
      end_date
    ]
  }
}

resource "random_password" "application_server_password" {
  length           = 48
  special          = true
  override_special = "!-_="

  keepers = {
    service_principal = azuread_service_principal.aadAppAksServer.id
  }
}

resource "azuread_application" "aadAppAksClient" {
  name       = "${local.spNamePrefix}-${var.subscriptionCommonName}-${var.environmentShort}-${var.commonName}-aksclient"
  reply_urls = ["http://${local.spNamePrefix}-${var.environmentShort}-${var.commonName}-aksclient"]
  type       = "native"

  required_resource_access {
    # Windows Azure Active Directory API
    resource_app_id = "00000002-0000-0000-c000-000000000000"

    resource_access {
      # DELEGATED PERMISSIONS: "Sign in and read user profile":
      # 311a71cc-e848-46a1-bdf8-97ff7156d8e6
      id   = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
      type = "Scope"
    }
  }

  required_resource_access {
    # AKS ad application server
    resource_app_id = azuread_application.aadAppAksServer.application_id

    resource_access {
      # Server app Oauth2 permissions id
      id = [for permission in azuread_application.aadAppAksServer.oauth2_permissions : permission.id][0]
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "aadAppAksClient" {
  application_id = azuread_application.aadAppAksClient.application_id
}

resource "azuread_application_password" "aadAppAksClient" {
  application_object_id = azuread_application.aadAppAksClient.id
  value                 = random_password.application_client_password.result
  end_date              = timeadd(timestamp(), "87600h") # 10 years

  lifecycle {
    ignore_changes = [
      end_date
    ]
  }
}

resource "random_password" "application_client_password" {
  length           = 48
  special          = true
  override_special = "!-_="

  keepers = {
    service_principal = azuread_service_principal.aadAppAksClient.id
  }
}

resource "azurerm_key_vault_secret" "kvSecretAksAadApps" {
  for_each = {
    for envResource in local.envResources :
    envResource => envResource
  }

  name = "aks-aad-apps"
  value = jsonencode({
    aksClientAppClientId     = azuread_application.aadAppAksClient.application_id
    aksClientAppPrincipalId  = azuread_service_principal.aadAppAksClient.object_id
    aksClientAppClientSecret = azuread_application_password.aadAppAksClient.value
    aksServerAppClientId     = azuread_application.aadAppAksServer.application_id
    aksServerAppClientSecret = azuread_application_password.aadAppAksServer.value
  })
  key_vault_id = data.azurerm_key_vault.coreKv[each.key].id
}
