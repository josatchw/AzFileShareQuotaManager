targetScope = 'resourceGroup'

var namePrefix = 'quotamgr3'
var location = resourceGroup().location
var quota = 100
var FSstorageAccountName = 'fs${namePrefix}${uniqueString(resourceGroup().id)}'
var QUstorageAccountName = 'qu${namePrefix}${uniqueString(resourceGroup().id)}'
//var appName = 'app${namePrefix}${uniqueString(resourceGroup().id)}'
// storage accounts must be between 3 and 24 characters in length and use numbers and lower-case letters only
var storageAccountName = 'ap${namePrefix}${uniqueString(resourceGroup().id)}'
var hostingPlanName = 'apphp${namePrefix}${uniqueString(resourceGroup().id)}'
var appInsightsName = 'appin${namePrefix}${uniqueString(resourceGroup().id)}'
var functionAppName = 'app${namePrefix}'

resource fileStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: FSstorageAccountName
  location: location
  kind: 'FileStorage'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    accessTier: 'Premium'
  }
  tags: {
    'autogrow': 'true'
    'watermark': '15'
    'quotagrowth': '15'
  }
}

var fileShareName = 'testshare1'
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-06-01' = {
  name: '${fileStorageAccount.name}/default/${fileShareName}'
  properties: {
    enabledProtocols: 'SMB'
    shareQuota: quota
  }
}

resource queueStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: QUstorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  resource queueService 'queueServices@2021-06-01' = {
    name: 'default'
    resource queue 'queues@2021-06-01' = {
      name: 'expandfsquota'
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
    'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppName}': 'Resource'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    httpsOnly: true
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: true
    siteConfig: {
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~4'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'powershell'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        // WEBSITE_CONTENTSHARE will also be auto-generated - https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_contentshare
        // WEBSITE_RUN_FROM_PACKAGE will be set to 1 by func azure functionapp publish
        {
          name: 'targetSubscriptionId'
          value: 'XXXXXXXXXXXXXXXXXXXXX'
        }
        {
          name: 'tag_autogrow'
          value: 'autogrow'
        }
        {
          name: 'tag_quotagrowth'
          value: 'quotagrowth'
        }
        {
          name: 'tag_watermark'
          value: 'watermark'
        }
      ]
    }
  }

  dependsOn: [
    appInsights
    hostingPlan
    storageAccount
  ]
  resource webconfig 'config@2021-02-01' = {
    name: 'web'
    properties: {
      powerShellVersion: '~7'
    }
  }
}
