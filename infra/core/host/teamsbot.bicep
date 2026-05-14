// Web App + User-Assigned Managed Identity for the Teams bot.
// Hosted on the same App Service Plan as the front-end web app.

@description('Name of the App Service that hosts the Teams bot.')
param name string

@description('Name of the User-Assigned Managed Identity used by the bot.')
param identityName string

param location string = resourceGroup().location
param tags object = {}

@description('Resource ID of the App Service Plan that will host the bot.')
param appServicePlanId string

@description('App Insights name. Leave empty to skip wiring App Insights.')
param applicationInsightsName string = ''
@description('Resource group containing App Insights. Required when applicationInsightsName is set.')
param applicationInsightsResourceGroupName string = ''

@description('Orchestrator endpoint URL (e.g. https://<func>.azurewebsites.net/api/orc).')
param orchestratorEndpoint string

@description('Storage account name that holds source documents.')
param storageAccountName string = ''

@description('Container in the storage account that holds source documents.')
param storageContainerName string = 'documents'

@description('Enable VNet integration for the web app.')
param networkIsolation bool = false
param vnetName string = ''
param subnetId string = ''

@description('Allow basic publishing credentials. Required for zip deploy when network isolated.')
param basicPublishingCredentials bool = false

@description('Additional app settings to merge into the web app configuration.')
param appSettings array = []

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  scope: resourceGroup(applicationInsightsResourceGroupName)
  name: applicationInsightsName
}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    virtualNetworkSubnetId: networkIsolation ? subnetId : null
    vnetRouteAllEnabled: networkIsolation
    siteConfig: {
      vnetName: networkIsolation ? vnetName : null
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      appSettings: concat(
        [
          {
            name: 'RUNNING_ON_AZURE'
            value: '1'
          }
          {
            name: 'CLIENT_ID'
            value: identity.properties.clientId
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: identity.properties.clientId
          }
          {
            name: 'TENANT_ID'
            value: identity.properties.tenantId
          }
          {
            name: 'BOT_TYPE'
            value: 'UserAssignedMsi'
          }
          {
            name: 'ORCHESTRATOR_ENDPOINT'
            value: orchestratorEndpoint
          }
          {
            name: 'STORAGE_ACCOUNT'
            value: storageAccountName
          }
          {
            name: 'STORAGE_CONTAINER'
            value: storageContainerName
          }
          {
            name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
            value: 'true'
          }
          {
            name: 'ENABLE_ORYX_BUILD'
            value: 'true'
          }
        ],
        empty(applicationInsightsName) ? [] : [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsights.properties.ConnectionString
          }
        ],
        appSettings
      )
    }
  }

  resource basicPublishingCredentialsPoliciesFtp 'basicPublishingCredentialsPolicies' = {
    name: 'ftp'
    properties: {
      allow: basicPublishingCredentials
    }
  }

  resource basicPublishingCredentialsPoliciesScm 'basicPublishingCredentialsPolicies' = {
    name: 'scm'
    properties: {
      allow: basicPublishingCredentials
    }
  }
}

output name string = webApp.name
output id string = webApp.id
output uri string = 'https://${webApp.properties.defaultHostName}'
output defaultHostName string = webApp.properties.defaultHostName
output identityName string = identity.name
output identityId string = identity.id
output identityClientId string = identity.properties.clientId
output identityPrincipalId string = identity.properties.principalId
output identityTenantId string = identity.properties.tenantId
