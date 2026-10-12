# Run this root as the authorized bootstrap identity, not the learner.
# The resource group is supplied by the lab host and is never owned by this state.
terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.9.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.13.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.10.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3.0"
    }
  }
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
  # resource_providers_to_register = [
  #   "Microsoft.ContainerService",
  #   "Microsoft.OperationalInsights",
  #   "Microsoft.OperationalInsights",
  #   "Microsoft.CognitiveServices",
  #   "Microsoft.ManagedIdentity",
  #   "Microsoft.PolicyInsights",
  #   "Microsoft.Monitor",
  #   "Microsoft.AlertsManagement"
  # ]
}

# resource "azurerm_resource_provider_feature_registration" "example" {
#   name          = "OtlpApplicationInsights"
#   provider_name = "Microsoft.Insights"
# }

provider "azuread" {
  tenant_id = data.azurerm_client_config.current.tenant_id
}

provider "helm" {
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.control.kube_config[0].host
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.control.kube_config[0].cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli",
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      ]
    }
  }
}

variable "resource_group_name" {
  description = "Existing, dedicated learner resource group. Bootstrap never creates or deletes it."
  type        = string
}

variable "lab_id" {
  description = "Unique learner instance ID, four to twelve lowercase letters or digits."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{4,12}$", var.lab_id))
    error_message = "Use four to twelve lowercase letters or digits."
  }
}

variable "learner_object_id" {
  description = "Existing lab user's object ID. Supply this or learner_upn, but not both. This path skips the directory lookup."
  type        = string
  default     = null
  validation {
    condition     = var.learner_object_id == null ? true : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.learner_object_id))
    error_message = "Supply the existing lab user's object ID."
  }
  validation {
    condition     = (var.learner_object_id != null) != (var.learner_upn != null)
    error_message = "Supply exactly one of learner_object_id or learner_upn."
  }
}

variable "learner_upn" {
  description = "Existing lab user's UPN in the subscription tenant. Used for a Microsoft Graph lookup only when learner_object_id is omitted."
  type        = string
  default     = null
  validation {
    condition     = var.learner_upn == null ? true : can(regex("^[^@\\s]+@[^@\\s]+$", var.learner_upn))
    error_message = "Supply a user principal name such as learner@example.com."
  }
}

variable "bootstrap_principal_type" {
  description = "Principal type of the identity executing Terraform."
  type        = string
  default     = "User"
  validation {
    condition     = contains(["User", "ServicePrincipal"], var.bootstrap_principal_type)
    error_message = "Use User or ServicePrincipal."
  }
}

variable "control_vm_size" {
  type        = string
  default     = "Standard_D4s_v6"
  description = "One non-HA control node. Confirm regional SKU quota before rehearsal."
}

variable "control_kubernetes_version" {
  type        = string
  default     = null
  description = "Optional approved control-cluster version. Automatic manages its own version; record both observed versions at rehearsal."
}

variable "argocd_extension_version" {
  type        = string
  default     = null
  description = "Optional approved extension version; otherwise use the service's Stable release and record its resolved version."
}

variable "model_name" {
  type        = string
  default     = "gpt-5.4-mini"
  description = "Model supported by the application and available in the resource group's region."
}

variable "model_version" {
  type        = string
  default     = "2026-03-17"
  description = "Azure model version, not the deployment name."
}

variable "model_capacity" {
  type        = number
  default     = 10
  description = "GlobalStandard capacity units, not a spending cap. Units depend on the selected model."
  validation {
    condition     = var.model_capacity > 0 && floor(var.model_capacity) == var.model_capacity
    error_message = "Model capacity must be a positive integer."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Organizer tags, including expiry and cost ownership where required by the lab host."
}

data "azurerm_client_config" "current" {}

data "azuread_user" "learner" {
  count               = var.learner_upn != null ? 1 : 0
  user_principal_name = var.learner_upn
}

data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

locals {
  learner_object_id = var.learner_object_id != null ? var.learner_object_id : data.azuread_user.learner[0].object_id
  prefix            = "prel37-${var.lab_id}"
  tags = merge(var.tags, {
    project    = "ignite26-prel37"
    lab-id     = var.lab_id
    managed-by = "terraform"
  })
  operators = merge({
    learner = {
      object_id      = local.learner_object_id
      principal_type = "User"
    }
    }, data.azurerm_client_config.current.object_id == local.learner_object_id ? {} : {
    bootstrap = {
      object_id      = data.azurerm_client_config.current.object_id
      principal_type = var.bootstrap_principal_type
    }
  })
  cluster_ids = {
    control  = azurerm_kubernetes_cluster.control.id
    workload = azurerm_kubernetes_automatic_cluster.workload.id
  }
  cluster_access = merge([
    for operator, principal in local.operators : {
      for cluster, id in local.cluster_ids : "${operator}-${cluster}" => {
        scope          = id
        object_id      = principal.object_id
        principal_type = principal.principal_type
      }
    }
  ]...)
}

resource "azurerm_kubernetes_cluster" "control" {
  name                              = "aks-${local.prefix}-control"
  location                          = data.azurerm_resource_group.lab.location
  resource_group_name               = data.azurerm_resource_group.lab.name
  dns_prefix                        = "aks-${local.prefix}-control"
  kubernetes_version                = var.control_kubernetes_version
  sku_tier                          = "Free"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = true
  role_based_access_control_enabled = true
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"
  tags                              = local.tags

  default_node_pool {
    name       = "system"
    node_count = 1
    vm_size    = var.control_vm_size
    upgrade_settings {
      max_surge = "1"
    }
  }
  node_provisioning_profile {
    mode = "Manual"
  }
  identity {
    type = "SystemAssigned"
  }
  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    outbound_type       = "loadBalancer"
    load_balancer_sku   = "standard"
  }
}

resource "helm_release" "crossplane" {
  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  version          = "2.4.2"
  namespace        = "crossplane-system"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 900
  depends_on = [
    azurerm_role_assignment.operator_cluster_access,
    azurerm_role_assignment.operator_cluster_credentials,
  ]
}

resource "azurerm_kubernetes_automatic_cluster" "workload" {
  name                = "aks-${local.prefix}-workload"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.tags
  identity {
    type = "SystemAssigned"
  }
  web_app_routing_ingress {
    istio_enabled = true
  }
}

resource "azapi_update_resource" "add_cluster_features" {
  type        = "Microsoft.ContainerService/managedClusters@2026-08-02-preview"
  resource_id = azurerm_kubernetes_automatic_cluster.workload.id
  body = {
    properties = {
      addonProfiles = {
        omsagent = {
          enabled = true
          config = {
            logAnalyticsWorkspaceResourceID = azurerm_log_analytics_workspace.lab.id
            useAADAuth                      = "true"
          }
        }
      }
      azureMonitorProfile = {
        metrics = {
          enabled = true
          kubeStateMetrics = {
            metricLabelsAllowlist      = ""
            metricAnnotationsAllowList = ""
          }
        }
        containerInsights = {
          enabled                         = true
          logAnalyticsWorkspaceResourceId = azurerm_log_analytics_workspace.lab.id
        }
      }
      ingressProfile = {
        gatewayAPI = {
          installation = "Standard"
        }
        webAppRouting = {
          enabled = true
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
        }
      }
    }
  }
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                            = "law-${local.prefix}"
  location                        = data.azurerm_resource_group.lab.location
  resource_group_name             = data.azurerm_resource_group.lab.name
  sku                             = "PerGB2018"
  retention_in_days               = 30
  daily_quota_gb                  = 1
  allow_resource_only_permissions = true
  tags                            = local.tags
}

# Application telemetry metrics from OTLP-enabled Application Insights resources.
resource "azurerm_monitor_workspace" "lab" {
  name                = "amw-${local.prefix}"
  location            = data.azurerm_resource_group.lab.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_storage_account" "state" {
  name                             = "stp37${var.lab_id}${substr(sha256(data.azurerm_resource_group.lab.id), 0, 6)}"
  resource_group_name              = data.azurerm_resource_group.lab.name
  location                         = data.azurerm_resource_group.lab.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  min_tls_version                  = "TLS1_2"
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  tags                             = local.tags
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }
}

# ARM container creation avoids requiring storage data-plane access for the bootstrap caller.
resource "azapi_resource" "state_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = "namespace-state"
  parent_id = "${azurerm_storage_account.state.id}/blobServices/default"
  body = {
    properties = { publicAccess = "None" }
  }
}

resource "azurerm_cognitive_account" "model" {
  name                  = "aoai-${local.prefix}"
  custom_subdomain_name = "aoai-${local.prefix}"
  resource_group_name   = data.azurerm_resource_group.lab.name
  location              = data.azurerm_resource_group.lab.location
  kind                  = "OpenAI"
  sku_name              = "S0"
  local_auth_enabled    = false
  tags                  = local.tags
}

resource "azurerm_cognitive_deployment" "model" {
  name                 = "lab-model"
  cognitive_account_id = azurerm_cognitive_account.model.id
  sku {
    name     = "GlobalStandard"
    capacity = var.model_capacity
  }
  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }
}

resource "azurerm_user_assigned_identity" "lab" {
  for_each            = toset(["provisioner", "argocd"])
  name                = "id-${local.prefix}-${each.key}"
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_resource_group.lab.location
  tags                = local.tags
}

locals {
  federations = {
    provisioner = {
      identity = "provisioner"
      issuer   = azurerm_kubernetes_cluster.control.oidc_issuer_url
      subject  = "system:serviceaccount:crossplane-system:provider-opentofu"
    }
    argocd-controller = {
      identity = "argocd"
      issuer   = azurerm_kubernetes_cluster.control.oidc_issuer_url
      subject  = "system:serviceaccount:argocd:argocd-application-controller"
    }
    argocd-server = {
      identity = "argocd"
      issuer   = azurerm_kubernetes_cluster.control.oidc_issuer_url
      subject  = "system:serviceaccount:argocd:argocd-server"
    }
  }
}

resource "azurerm_federated_identity_credential" "lab" {
  for_each                  = local.federations
  name                      = each.key
  user_assigned_identity_id = azurerm_user_assigned_identity.lab[each.value.identity].id
  issuer                    = each.value.issuer
  subject                   = each.value.subject
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "operator_cluster_access" {
  for_each             = local.cluster_access
  scope                = each.value.scope
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value.object_id
  principal_type       = each.value.principal_type
}

resource "azurerm_role_assignment" "operator_cluster_credentials" {
  for_each             = local.cluster_access
  scope                = each.value.scope
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.value.object_id
  principal_type       = each.value.principal_type
}

resource "azurerm_role_assignment" "provisioner_namespace" {
  scope                = azurerm_kubernetes_automatic_cluster.workload.id
  role_definition_name = "Azure Kubernetes Service Namespace Contributor"
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "provisioner_read" {
  scope                = data.azurerm_resource_group.lab.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "provisioner_app_resources" {
  for_each             = toset(["Managed Identity Contributor", "Monitoring Contributor"])
  scope                = data.azurerm_resource_group.lab.id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
}

# OTLP-enabled Application Insights makes Azure create its DCE and DCR in an ai_<name>_<appId>_managed resource
# group using the caller's rights. The provisioner is a platform identity; developers never hold these rights.
resource "azurerm_role_definition" "provisioner_otlp" {
  name              = "PREL37 OTLP telemetry vending (${var.lab_id})"
  scope             = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  description       = "Lets the PREL37 provisioner create OTLP-enabled Application Insights and its Azure-managed DCE, DCR, and resource group."
  assignable_scopes = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/resourceGroups/write",
      "Microsoft.Resources/subscriptions/resourceGroups/delete",
      "Microsoft.Insights/dataCollectionRules/*",
      "Microsoft.Insights/dataCollectionEndpoints/*",
    ]
  }
}

resource "azurerm_role_assignment" "provisioner_otlp" {
  scope              = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_id = azurerm_role_definition.provisioner_otlp.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type     = "ServicePrincipal"
}

# Azure creates the DCR outside the lab resource group. Delegate only telemetry-publisher grants.
resource "azurerm_role_assignment" "provisioner_otlp_grants" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<-CONDITION
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {3913510d-42f4-4e42-8a64-420c390055eb}
        AND
        @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
      )
    )
    AND
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      OR (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {3913510d-42f4-4e42-8a64-420c390055eb}
        AND
        @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
      )
    )
  CONDITION
}

# Delegate only model-user grants to service principals on this model account.
resource "azurerm_role_assignment" "provisioner_model_grants" {
  scope                = azurerm_cognitive_account.model.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<-CONDITION
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {5e0bd9bd-7b93-4f28-af87-19fc36ad61bd}
        AND
        @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
      )
    )
    AND
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      OR (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {5e0bd9bd-7b93-4f28-af87-19fc36ad61bd}
        AND
        @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
      )
    )
  CONDITION
}

# Delegate only AKS desktop project grants (Cluster User, Namespace User, RBAC Writer) to users or groups on the workload cluster.
resource "azurerm_role_assignment" "provisioner_namespace_grants" {
  scope                = azurerm_kubernetes_automatic_cluster.workload.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<-CONDITION
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {4abbcc35-e782-43d8-92c5-2d3f1bd2253f, c9f76ca8-b262-4b10-8ed2-09cf0948aa35, a7ffa36f-339b-4b5c-8bdf-e2c188b2c0eb}
        AND
        @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'User', 'Group'}
      )
    )
    AND
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      OR (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {4abbcc35-e782-43d8-92c5-2d3f1bd2253f, c9f76ca8-b262-4b10-8ed2-09cf0948aa35, a7ffa36f-339b-4b5c-8bdf-e2c188b2c0eb}
        AND
        @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'User', 'Group'}
      )
    )
  CONDITION
}

# Delegate only Monitoring Reader to users or groups, so vending can give requesters read access to their own
# Application Insights resource. The module, not the requester, chooses the assignment scope.
resource "azurerm_role_assignment" "provisioner_monitoring_grants" {
  scope                = data.azurerm_resource_group.lab.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<-CONDITION
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {43d0d8ad-25c7-4714-9337-8ba259a9fe05}
        AND
        @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'User', 'Group'}
      )
    )
    AND
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      OR (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {43d0d8ad-25c7-4714-9337-8ba259a9fe05}
        AND
        @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'User', 'Group'}
      )
    )
  CONDITION
}

resource "azurerm_role_assignment" "provisioner_state" {
  scope                = azapi_resource.state_container.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.lab["provisioner"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "argocd_workload" {
  scope                = azurerm_kubernetes_automatic_cluster.workload.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.lab["argocd"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster_extension" "argocd" {
  name              = "argocd"
  cluster_id        = azurerm_kubernetes_cluster.control.id
  extension_type    = "Microsoft.ArgoCD"
  release_train     = "Stable"
  version           = var.argocd_extension_version
  release_namespace = "argocd"
  configuration_settings = merge({
    "fullnameOverride"                                = "argocd"
    "redis-ha.enabled"                                = "false"
    "controller.replicas"                             = "1"
    "server.replicas"                                 = "1"
    "repoServer.replicas"                             = "1"
    "server.service.type"                             = "ClusterIP"
    "configs.cm.url"                                  = "https://localhost:8443"
    "configs.cm.admin\\.enabled"                      = "true"
    "configs.cm.application\\.resourceTrackingMethod" = "annotation"
    # Use deployment identity without the extension's repo-server/Entra SSO helper.
    "azure.workloadIdentity.enabled"       = "false"
    "configs.cm.resource\\.customizations" = <<-YAML
      platform.prel37.example/AppEnvironment:
        health.lua: |
          local result = { status = "Progressing", message = "Waiting for namespace and baseline" }
          if obj.status ~= nil and obj.status.conditions ~= nil then
            for _, condition in ipairs(obj.status.conditions) do
              if condition.type == "Synced" and condition.status == "False" then
                return { status = "Degraded", message = condition.message or condition.reason or "Reconciliation failed" }
              end
              if condition.type == "Ready" and condition.status == "True" then
                result = { status = "Healthy", message = "Namespace and baseline are ready" }
              end
            end
          end
          return result
      argoproj.io/Application:
        health.lua: |
          if obj.status ~= nil and obj.status.health ~= nil then
            return { status = obj.status.health.status, message = obj.status.health.message or "" }
          end
          return { status = "Progressing", message = "Waiting for child application" }
    YAML
    }, merge([
      for component in ["controller", "server"] : {
        "${component}.podLabels.azure\\.workload\\.identity/use"                             = "null"
        "${component}.serviceAccount.annotations.azure\\.workload\\.identity/client-id"      = azurerm_user_assigned_identity.lab["argocd"].client_id
        "${component}.serviceAccount.annotations.azure\\.workload\\.identity/tenant-id"      = data.azurerm_client_config.current.tenant_id
        "${component}.env[0].name"                                                           = "AZURE_CLIENT_ID"
        "${component}.env[0].value"                                                          = azurerm_user_assigned_identity.lab["argocd"].client_id
        "${component}.env[1].name"                                                           = "AZURE_TENANT_ID"
        "${component}.env[1].value"                                                          = data.azurerm_client_config.current.tenant_id
        "${component}.env[2].name"                                                           = "AZURE_FEDERATED_TOKEN_FILE"
        "${component}.env[2].value"                                                          = "/var/run/secrets/azure/tokens/azure-identity-token"
        "${component}.env[3].name"                                                           = "AZURE_AUTHORITY_HOST"
        "${component}.env[3].value"                                                          = "https://login.microsoftonline.com/"
        "${component}.volumes[0].name"                                                       = "azure-identity-token"
        "${component}.volumes[0].projected.sources[0].serviceAccountToken.audience"          = "api://AzureADTokenExchange"
        "${component}.volumes[0].projected.sources[0].serviceAccountToken.expirationSeconds" = "3600"
        "${component}.volumes[0].projected.sources[0].serviceAccountToken.path"              = "azure-identity-token"
        "${component}.volumeMounts[0].name"                                                  = "azure-identity-token"
        "${component}.volumeMounts[0].mountPath"                                             = "/var/run/secrets/azure/tokens"
        "${component}.volumeMounts[0].readOnly"                                              = "true"
      }
  ]...))
  depends_on = [azurerm_federated_identity_credential.lab]
}

output "lab" {
  description = "Non-token VM configuration. Export with terraform output -json lab > lab.json."
  sensitive   = true
  value = {
    LAB_ID                      = var.lab_id
    AZURE_SUBSCRIPTION_ID       = data.azurerm_client_config.current.subscription_id
    AZURE_TENANT_ID             = data.azurerm_client_config.current.tenant_id
    AZURE_LOCATION              = data.azurerm_resource_group.lab.location
    AKS_RESOURCE_GROUP          = data.azurerm_resource_group.lab.name
    CONTROL_CLUSTER_NAME        = azurerm_kubernetes_cluster.control.name
    AKS_CLUSTER_NAME            = azurerm_kubernetes_automatic_cluster.workload.name
    WORKLOAD_CLUSTER_ID         = azurerm_kubernetes_automatic_cluster.workload.id
    WORKLOAD_OIDC_ISSUER        = azurerm_kubernetes_automatic_cluster.workload.oidc_issuer_url
    WORKLOAD_SERVER             = azurerm_kubernetes_automatic_cluster.workload.kube_config[0].host
    WORKLOAD_CA                 = azurerm_kubernetes_automatic_cluster.workload.kube_config[0].cluster_ca_certificate
    PROVISIONER_CLIENT_ID       = azurerm_user_assigned_identity.lab["provisioner"].client_id
    ARGO_CLIENT_ID              = azurerm_user_assigned_identity.lab["argocd"].client_id
    MODEL_RESOURCE_ID           = azurerm_cognitive_account.model.id
    MODEL_ENDPOINT              = "${trimsuffix(azurerm_cognitive_account.model.endpoint, "/")}/openai/v1/"
    MODEL_DEPLOYMENT            = azurerm_cognitive_deployment.model.name
    LOG_ANALYTICS_WORKSPACE_ID  = azurerm_log_analytics_workspace.lab.id
    AZURE_MONITOR_WORKSPACE_ID  = azurerm_monitor_workspace.lab.id
    CLUSTER_OPERATOR_OBJECT_IDS = join(",", [for operator in local.operators : operator.object_id])
    STATE_ACCOUNT               = azurerm_storage_account.state.name
    STATE_CONTAINER             = azapi_resource.state_container.name
    STATE_KEY                   = "${var.lab_id}/environment.tfstate"
  }
}
