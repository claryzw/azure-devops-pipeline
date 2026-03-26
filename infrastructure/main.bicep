// ============================================================================
// Azure DevOps Pipeline — Infrastructure as Code
// Description: Deploys all Azure resources for the CI/CD pipeline project
// Author: Clarence Itai Msindo
// ============================================================================

// --- Parameters (values passed in at deployment time) --- 

@description('Azure region for all resources')
param location string = 'australiaeast'

@description('Unique prefix for resource names to avoid naming conflicts')
@minLength(3)
@maxLength(10)
param projectPrefix string = 'devpipe'

@description('Environment name')
@allowed([
  'dev'
  'prod'
])
param environment string = 'dev'

@description('Email address for monitoring alerts')
param alertEmail string

// --- Variables (computed values used throughout the template) ---
// These build consistent names for all resources using the prefix

var uniqueSuffix = uniqueString(resourceGroup().id)
var containerRegistryName = '${projectPrefix}acr${uniqueSuffix}'
var appServicePlanName = '${projectPrefix}-plan-${environment}'
var webAppName = '${projectPrefix}-app-${environment}-${uniqueSuffix}'
var appInsightsName = '${projectPrefix}-insights-${environment}'
var logAnalyticsName = '${projectPrefix}-logs-${environment}'
var actionGroupName = '${projectPrefix}-alerts-${environment}'

// ============================================================================
// RESOURCES
// ============================================================================

// --- 1. Log Analytics Workspace ---
// Collects and stores logs from Application Insights
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'  // Free tier: 5GB/month included
    }
    retentionInDays: 30   // Keep logs for 30 days (free tier limit)
  }
}

// --- 2. Application Insights ---
// Monitors Flask app's performance, errors, and usage
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id  // Sends data to Log Analytics
    RetentionInDays: 30
  }
}

// --- 3. Azure Container Registry (ACR) ---
// Private registry to store Docker images
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'  // Free tier: 10GB storage, 2 webhooks
  }
  properties: {
    adminUserEnabled: true  // Needed for App Service to pull images
  }
}

// --- 4. App Service Plan ---
// The compute resource that runs the web app
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'           // Linux-based (matches your Docker container)
  sku: {
    name: 'F1'            // Free tier: 60 min CPU/day, 1GB RAM
    tier: 'Free'
  }
  properties: {
    reserved: true         // Required for Linux App Service Plans
  }
}

// --- 5. Web App (Container) ---
// Flask application running as a Docker container
// This pulls the image from ACR and runs it on the App Service Plan
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id  // Runs on the plan we created above
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.properties.loginServer}/flask-app:latest'
      alwaysOn: false       // Must be false on Free tier
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.properties.loginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.listCredentials().username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'    // Container apps don't need persistent storage
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITES_PORT'
          value: '8000'     // Must match the port in your Dockerfile/gunicorn
        }
      ]
    }
    httpsOnly: true          // Security: force HTTPS only
  }
}

// --- 6. Action Group (for alert notifications) ---
// Defines WHO gets notified when something goes wrong
resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: actionGroupName
  location: 'global'        // Action groups are always global
  properties: {
    groupShortName: 'DevPipeAlrt'
    enabled: true
    emailReceivers: [
      {
        name: 'AdminEmail'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// --- 7. Alert Rule: Slow Response Time ---
// Triggers when average response time exceeds 2 seconds for 5 minutes
resource responseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${projectPrefix}-slow-response-${environment}'
  location: 'global'        // Metric alerts are always global
  properties: {
    description: 'Alert when average response time exceeds 2 seconds'
    severity: 2              // 0=Critical, 1=Error, 2=Warning, 3=Info, 4=Verbose
    enabled: true
    scopes: [
      webApp.id              // Monitor the web app we created
    ]
    evaluationFrequency: 'PT1M'   // Check every 1 minute
    windowSize: 'PT5M'            // Look at the last 5 minutes of data
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighResponseTime'
          metricName: 'HttpResponseTime'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 2        // 2 seconds
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// --- 8. Alert Rule: High Failure Rate ---
// Triggers when more than 5 failed requests occur in a 5-minute window
resource failureRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${projectPrefix}-high-failures-${environment}'
  location: 'global'
  properties: {
    description: 'Alert when failed request rate exceeds 5 percent'
    severity: 1
    enabled: true
    scopes: [
      webApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighFailureRate'
          metricName: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}


// ============================================================================
// OUTPUTS
// ============================================================================
// These values are printed after deployment — useful for the CI/CD pipeline

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output acrLoginServer string = containerRegistry.properties.loginServer
output appInsightsKey string = appInsights.properties.InstrumentationKey
output webAppName string = webApp.name
output resourceGroupName string = resourceGroup().name