# Executed only by provider-opentofu. Never apply this root from the learner VM.
terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    azurerm = {
      source  = "registry.opentofu.org/hashicorp/azurerm"
      version = "= 5.9.0"
    }
    azapi = {
      source  = "registry.terraform.io/Azure/azapi"
      version = "= 2.13.0"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

provider "azapi" {
  skip_provider_registration = true
}

variable "cluster_id" {
  type        = string
  description = "Bootstrap-approved workload cluster resource ID."
}

variable "location" {
  type = string
}

variable "lab_id" {
  type = string
}

variable "resource_group_name" {
  type        = string
  description = "Bootstrap-approved resource group for application resources."
}

variable "workload_oidc_issuer" {
  type        = string
  description = "Workload cluster issuer, not the control cluster issuer."
}

variable "model_resource_id" {
  type        = string
  description = "Existing shared model account. Vending grants access but does not own it."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing shared workspace for application telemetry."
}

variable "azure_monitor_workspace_id" {
  type        = string
  description = "Existing shared Azure Monitor workspace for OTLP application metrics."
}

variable "team" {
  type        = string
  description = "Application team. Names the managed namespace and the team's Azure resources."
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,18}[a-z0-9])?$", var.team)) && !startswith(var.team, "kube-") && !contains(["default", "argocd", "platform-gateway", "gatekeeper-system", "app-routing-system", "aks-istio-system"], var.team)
    error_message = "team must be a lowercase DNS label of at most 20 characters and must not be a system namespace."
  }
}

variable "application" {
  type        = string
  description = "Application name, recorded on the namespace and resource tags."
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,38}[a-z0-9])?$", var.application))
    error_message = "application must be a lowercase DNS label of at most 40 characters."
  }
}

variable "agents" {
  type        = list(string)
  description = "Model-calling components of the approved chart. Each gets its own ServiceAccount, Azure identity, and model role."
  validation {
    condition     = length(var.agents) > 0 && length(var.agents) == length(distinct(var.agents)) && alltrue([for a in var.agents : can(regex("^[a-z]([a-z0-9-]{0,18}[a-z0-9])?$", a))])
    error_message = "agents must be a nonempty list of distinct lowercase DNS labels of at most 20 characters."
  }
}

variable "owner" {
  type        = string
  description = "Backstage catalog owner, recorded as a namespace annotation."
  validation {
    condition     = can(regex("^group:default/[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.owner))
    error_message = "owner must have the form group:default/<name>."
  }
}

variable "cost_center" {
  type = string
  validation {
    condition     = can(regex("^CC-[0-9]{4}$", var.cost_center))
    error_message = "Cost center must have the form CC-1234."
  }
}

variable "requester_object_id" {
  type        = string
  default     = ""
  description = "Entra user or group that gets AKS desktop project access. Empty skips the grants."
  validation {
    condition     = var.requester_object_id == "" || (can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.requester_object_id)) && var.requester_object_id != "00000000-0000-0000-0000-000000000000")
    error_message = "requesterObjectId must be a real Entra object ID, not the example placeholder."
  }
}

variable "requester_principal_type" {
  type    = string
  default = "User"
  validation {
    condition     = contains(["User", "Group"], var.requester_principal_type)
    error_message = "requesterPrincipalType must be User or Group."
  }
}

variable "cluster_operator_object_ids" {
  type        = string
  default     = ""
  description = "Comma-separated object IDs that bootstrap already granted Cluster User on the workload cluster. Azure rejects duplicate assignments."
}

locals {
  prefix            = "prel37-${var.lab_id}"
  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  tags = {
    project     = "ignite26-prel37"
    lab-id      = var.lab_id
    team        = var.team
    application = var.application
    cost-center = var.cost_center
    managed-by  = "provider-opentofu"
  }
}

data "azurerm_client_config" "current" {}

# One identity per agent, trusted only for the ServiceAccount of the same name, so model calls
# are attributable to the agent that made them and each agent's access can be revoked on its own.
resource "azurerm_user_assigned_identity" "agent" {
  for_each            = toset(var.agents)
  name                = "id-${local.prefix}-${var.team}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(local.tags, { agent = each.key })
}

resource "azurerm_federated_identity_credential" "agent" {
  for_each                  = azurerm_user_assigned_identity.agent
  name                      = "${var.team}-${each.key}"
  user_assigned_identity_id = each.value.id
  issuer                    = var.workload_oidc_issuer
  subject                   = "system:serviceaccount:${var.team}:${each.key}"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "model_access" {
  for_each                         = azurerm_user_assigned_identity.agent
  scope                            = var.model_resource_id
  role_definition_name             = "Cognitive Services OpenAI User"
  principal_id                     = each.value.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# OTLP-enabled Application Insights. Azure creates its ingestion DCE and DCR in an ai_<name>_<appId>_managed
# resource group using the provisioner's subscription-scoped vending role.
resource "azapi_resource" "app_insights" {
  type      = "Microsoft.Insights/components@2025-01-23-preview"
  name      = "appi-${local.prefix}-${var.team}"
  parent_id = local.resource_group_id
  location  = var.location
  tags      = local.tags

  schema_validation_enabled = false

  body = {
    kind = "web"
    properties = {
      Application_Type                   = "web"
      Flow_Type                          = "Redfield"
      Request_Source                     = "IbizaAIExtension"
      IngestionMode                      = "LogAnalytics"
      RetentionInDays                    = 30
      WorkspaceResourceId                = var.log_analytics_workspace_id
      AzureMonitorWorkspaceResourceId    = var.azure_monitor_workspace_id
      AzureMonitorWorkspaceIngestionMode = "Enabled"
      DisableLocalAuth                   = true
      publicNetworkAccessForIngestion    = "Enabled"
      publicNetworkAccessForQuery        = "Enabled"
    }
  }

  response_export_values = [
    "properties.ConnectionString",
    "properties.DataCollectionRuleResourceId",
  ]
}

data "azapi_resource" "app_otlp_rule" {
  type                   = "Microsoft.Insights/dataCollectionRules@2024-03-11"
  resource_id            = azapi_resource.app_insights.output.properties.DataCollectionRuleResourceId
  response_export_values = ["properties"]

  lifecycle {
    postcondition {
      condition = (
        length(try(self.output.properties.directDataSources.otelTraces, [])) > 0 &&
        length(try(self.output.properties.directDataSources.otelLogs, [])) > 0 &&
        length(distinct(flatten([for source in try(self.output.properties.directDataSources.otelMetrics, []) : source.streams]))) == 1
      )
      error_message = "The Application Insights DCR must support direct OTLP traces and logs and expose exactly one metrics stream. Check its OTLP Connection Info."
    }
  }
}

data "azapi_resource" "app_otlp_endpoint" {
  type                   = "Microsoft.Insights/dataCollectionEndpoints@2024-03-11"
  resource_id            = data.azapi_resource.app_otlp_rule.output.properties.dataCollectionEndpointId
  response_export_values = ["properties.logsIngestion.endpoint", "properties.metricsIngestion.endpoint"]
}

locals {
  otlp_rule_path      = "/datacollectionRules/${data.azapi_resource.app_otlp_rule.output.properties.immutableId}/streams"
  otlp_metrics_stream = one(distinct(flatten([for source in data.azapi_resource.app_otlp_rule.output.properties.directDataSources.otelMetrics : source.streams])))
}

resource "azurerm_role_assignment" "telemetry_access" {
  for_each                         = azurerm_user_assigned_identity.agent
  scope                            = azapi_resource.app_insights.output.properties.DataCollectionRuleResourceId
  role_definition_name             = "Monitoring Metrics Publisher"
  principal_id                     = each.value.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azapi_resource" "namespace" {
  type      = "Microsoft.ContainerService/managedClusters/managedNamespaces@2026-03-01"
  name      = var.team
  parent_id = var.cluster_id
  location  = var.location
  body = {
    properties = {
      adoptionPolicy = "Never"
      deletePolicy   = "Delete"
      defaultResourceQuota = {
        cpuRequest    = "2000m"
        cpuLimit      = "6000m"
        memoryRequest = "3Gi"
        memoryLimit   = "8Gi"
      }
      defaultNetworkPolicy = {
        ingress = "AllowSameNamespace"
        egress  = "AllowAll"
      }
      labels = {
        "app.kubernetes.io/part-of"              = var.application
        "platform.prel37.example/cost-center"    = var.cost_center
        "platform.prel37.example/gateway-access" = "enabled"
        "headlamp.dev/project-id"                = var.team
        "headlamp.dev/project-managed-by"        = "aks-desktop"
        "aks-desktop/project-subscription"       = data.azurerm_client_config.current.subscription_id
        "aks-desktop/project-resource-group"     = var.resource_group_name
      }
      annotations = {
        "platform.prel37.example/owner" = var.owner
      }
    }
  }
}

locals {
  # AKS desktop project access: kubeconfig download, namespace visibility, and read/write inside the namespace only.
  # Monitoring Reader on the team's own Application Insights resource lets the requester see their telemetry.
  requester_has_cluster_user = contains([for id in split(",", lower(var.cluster_operator_object_ids)) : trimspace(id)], lower(var.requester_object_id))
  requester_roles = var.requester_object_id == "" ? {} : merge(local.requester_has_cluster_user ? {} : {
    cluster_user = { role = "Azure Kubernetes Service Cluster User Role", scope = var.cluster_id }
    }, {
    namespace_user    = { role = "Azure Kubernetes Service Namespace User", scope = azapi_resource.namespace.id }
    rbac_writer       = { role = "Azure Kubernetes Service RBAC Writer", scope = azapi_resource.namespace.id }
    monitoring_reader = { role = "Monitoring Reader", scope = azapi_resource.app_insights.id }
  })
}

resource "azurerm_role_assignment" "requester" {
  for_each             = local.requester_roles
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = var.requester_object_id
  principal_type       = var.requester_principal_type
}

output "namespace_id" {
  value = azapi_resource.namespace.id
}

output "namespace_name" {
  value = azapi_resource.namespace.name
}

output "agent_client_ids" {
  value      = { for agent, identity in azurerm_user_assigned_identity.agent : agent => identity.client_id }
  depends_on = [azurerm_federated_identity_credential.agent, azurerm_role_assignment.model_access]
}

output "appinsights_resource_id" {
  value = azapi_resource.app_insights.id
}

# Retained for older Composition revisions; direct OTLP does not authenticate with this value.
output "applicationinsights_connection_string" {
  value = azapi_resource.app_insights.output.properties.ConnectionString
}

output "otlp" {
  value = {
    traces_endpoint         = "${trimsuffix(data.azapi_resource.app_otlp_endpoint.output.properties.logsIngestion.endpoint, "/")}${local.otlp_rule_path}/Microsoft-OTLP-Traces/otlp/v1/traces"
    logs_endpoint           = "${trimsuffix(data.azapi_resource.app_otlp_endpoint.output.properties.logsIngestion.endpoint, "/")}${local.otlp_rule_path}/Microsoft-OTLP-Logs/otlp/v1/logs"
    metrics_endpoint        = "${trimsuffix(data.azapi_resource.app_otlp_endpoint.output.properties.metricsIngestion.endpoint, "/")}${local.otlp_rule_path}/${local.otlp_metrics_stream}/otlp/v1/metrics"
    application_id          = regex("InstrumentationKey=([^;]+)", azapi_resource.app_insights.output.properties.ConnectionString)[0]
    data_collection_rule_id = azapi_resource.app_insights.output.properties.DataCollectionRuleResourceId
  }
  depends_on = [azurerm_role_assignment.telemetry_access]
}
