@description ('Deployment location')
param location string = 'centralindia'

@description ('Standardized tags for resource governance')
param tags object = {
    Environment: 'Prod'
    Project: 'Telemetry'
}

@description('Name of Log Analytics Workspace')
param workspaceName string = 'la-telemetry-prod-centralindia-001'

@description ('Data retention in days for Log Analytics Workspace')
param dataRetention int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
    name: workspaceName
    location: location
    tags: tags
    properties: {
        sku: {
            name: 'PerGB2018'
        }
        retentionInDays: dataRetention
    }
}

output workspaceResourceId string = logAnalyticsWorkspace.id
