# outputs.tf
# Values printed after `terraform apply` completes.
# Used for quick access to resource details and for CI/CD integration.

output "resource_group_name" {
  description = "Name of the resource group holding all resources"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

output "acr_login_server" {
  description = "ACR login server URL - used by Docker to push/pull images"
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "ACR admin username - used by the Web App to pull images"
  value       = azurerm_container_registry.main.admin_username
}

output "acr_admin_password" {
  description = "ACR admin password - marked sensitive to hide from console output"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

output "web_app_name" {
  description = "Name of the Linux Web App"
  value       = azurerm_linux_web_app.main.name
}

output "web_app_url" {
  description = "Public HTTPS URL of the deployed Web App"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "application_insights_connection_string" {
  description = "App Insights connection string - used by the Flask app for telemetry"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID - used for querying logs"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}