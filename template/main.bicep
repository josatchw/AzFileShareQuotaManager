targetScope = 'resourceGroup'

var targetSubscriptionId = subscription()
var namePrefix = 'quotamgr3'
var location = resourceGroup().location
var quota = 100
var FSstorageAccountName = 'fs${namePrefix}${uniqueString(resourceGroup().id)}'
var MGstorageAccountName = 'mg${namePrefix}${uniqueString(resourceGroup().id)}'
// storage accounts must be between 3 and 24 characters in length and use numbers and lower-case letters only
var APstorageAccountName = 'ap${namePrefix}${uniqueString(resourceGroup().id)}'
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
  tags: {
    'autogrow': 'true'
    'watermark': '85'
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

resource mgmntStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: MGstorageAccountName
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
  resource blobLogs 'blobServices@2021-06-01' = {
    name: 'default'
    resource blob 'containers@2021-06-01' = {
      name: 'sharestats'
    }
  }
}

resource storageAccountAppService 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: APstorageAccountName
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountAppService.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccountAppService.id, storageAccountAppService.apiVersion).keys[0].value}'
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
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountAppService.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccountAppService.id, storageAccountAppService.apiVersion).keys[0].value}'
        }
        // WEBSITE_CONTENTSHARE will also be auto-generated - https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_contentshare
        // WEBSITE_RUN_FROM_PACKAGE will be set to 1 by func azure functionapp publish
        {
          name: 'targetSubscriptionId'
          value: targetSubscriptionId.subscriptionId
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
        {
          name: 'outputMessageQueue_STORAGE'
          value: queueStorageConn
        }
        {
          name: 'outputShareStats_STORAGE'
          value: shareStatsStorageConn
        }
      ]
    }
  }

  dependsOn: [
    appInsights
    hostingPlan
    storageAccountAppService
    mgmntStorageAccount
  ]
  resource webconfig 'config@2021-02-01' = {
    name: 'web'
    properties: {
      powerShellVersion: '~7'
    }
  }
}

var queueStorageConn = 'DefaultEndpointsProtocol=https;AccountName=${mgmntStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(mgmntStorageAccount.id, mgmntStorageAccount.apiVersion).keys[0].value}'
var shareStatsStorageConn = 'DefaultEndpointsProtocol=https;AccountName=${mgmntStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(mgmntStorageAccount.id, mgmntStorageAccount.apiVersion).keys[0].value}'
output queueStorageConnectionString string = queueStorageConn
