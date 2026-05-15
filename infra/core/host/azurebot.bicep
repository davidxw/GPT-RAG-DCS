// Azure Bot Service registration for the Teams bot.
// Uses an existing User-Assigned Managed Identity for the bot's MSA app identity.

@description('Name of the Azure Bot Service resource.')
param botServiceName string

@description('Display name shown in the Bot Framework / Teams.')
@maxLength(42)
param botDisplayName string

@description('SKU for the Azure Bot Service (e.g. F0 or S1).')
param botServiceSku string = 'F0'

@description('Default host name of the web app that implements the bot (without scheme).')
param botAppDomain string

@description('Client (application) ID of the User-Assigned Managed Identity used by the bot.')
param identityClientId string

@description('Tenant ID of the User-Assigned Managed Identity used by the bot.')
param identityTenantId string

@description('Resource ID of the User-Assigned Managed Identity used by the bot.')
param identityResourceId string

param tags object = {}

resource botService 'Microsoft.BotService/botServices@2022-09-15' = {
  name: botServiceName
  location: 'global'
  kind: 'azurebot'
  tags: tags
  sku: {
    name: botServiceSku
  }
  properties: {
    displayName: botDisplayName
    endpoint: 'https://${botAppDomain}/api/messages'
    msaAppId: identityClientId
    msaAppMSIResourceId: identityResourceId
    msaAppTenantId: identityTenantId
    msaAppType: 'UserAssignedMSI'
  }
}

resource botServiceMsTeamsChannel 'Microsoft.BotService/botServices/channels@2022-09-15' = {
  parent: botService
  name: 'MsTeamsChannel'
  location: 'global'
  properties: {
    channelName: 'MsTeamsChannel'
  }
}

output botServiceName string = botService.name
output botServiceId string = botService.id
