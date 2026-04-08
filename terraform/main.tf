# main.tf
# Defines all Azure resources for the DevOps pipeline project.
# This file is organised top-to-bottom by dependency order:
# foundation resources first, then app hosting, then monitoring.

# ---------------------------------------------------------------------------
# Local values - computed names used across multiple resources
# ---------------------------------------------------------------------------
locals {
  # Build consistent resource names from variables
  # Example: devopspipelinedevacr, devopspipeline-dev-plan
  acr_name          = "${var.project_name}${var.environment}acr"
  app_service_plan  = "${var.project_name}-${var.environment}-plan"
  web_app_name      = "${var.project_name}-${var.environment}-app"
  log_analytics     = "${var.project_name}-${var.environment}-logs"
  app_insights_name = "${var.project_name}-${var.environment}-insights"
  action_group_name = "${var.project_name}-${var.environment}-ag"
  alert_rule_name   = "${var.project_name}-${var.environment}-response-time-alert"
}

# ---------------------------------------------------------------------------
# Resource Group - the container for everything else
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace - backend storage for Application Insights
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Application Insights - application monitoring and telemetry
# ---------------------------------------------------------------------------
resource "azurerm_application_insights" "main" {
  name                = local.app_insights_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Azure Container Registry - stores Docker images built by the CI pipeline
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"
  admin_enabled       = true # Required for Web App to pull images using username/password
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# App Service Plan - the compute tier (Linux, Free F1)
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = local.app_service_plan
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "F1" # Free tier - protects your credits
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Linux Web App - runs the Docker container pulled from ACR
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "main" {
  name                = local.web_app_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  tags                = var.tags

  site_config {
    # F1 free tier does NOT support always_on - must be false
    always_on = false

    # Pull a placeholder image on first deploy
    # The GitHub Actions pipeline will swap this to the real image
    application_stack {
      docker_image_name        = "nginx:latest"
      docker_registry_url      = "https://${azurerm_container_registry.main.login_server}"
      docker_registry_username = azurerm_container_registry.main.admin_username
      docker_registry_password = azurerm_container_registry.main.admin_password
    }
  }

  app_settings = {
    # Application Insights connection - enables telemetry from the Flask app
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key

    # Standard Azure App Service container settings
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "WEBSITES_PORT"                       = "8000"

    # Note: Docker registry credentials are handled by application_stack block above.
    # In azurerm v4.x, setting DOCKER_REGISTRY_SERVER_* here is forbidden - the provider
    # manages them automatically from the application_stack configuration.
  }

  # Ignore changes to the Docker image tag - GitHub Actions manages this
  # Without this, every `terraform apply` would try to reset the image to nginx:latest
  lifecycle {
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
    ]
  }
}

# ---------------------------------------------------------------------------
# Action Group - defines WHO gets notified when an alert fires
# ---------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "main" {
  name                = local.action_group_name
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "devopsag" # Max 12 characters - shows in SMS/email subject
  tags                = var.tags

  email_receiver {
    name          = "primary-email"
    email_address = var.alert_email
  }
}

# ---------------------------------------------------------------------------
# Metric Alert - fires when average response time > 2 seconds over 5 minutes
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "response_time" {
  name                = local.alert_rule_name
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alerts when average server response time exceeds 2 seconds"
  severity            = 2      # 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose
  frequency           = "PT1M" # Check every 1 minute
  window_size         = "PT5M" # Evaluate over a 5-minute window
  tags                = var.tags

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 2000 # Milliseconds (2 seconds)
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}