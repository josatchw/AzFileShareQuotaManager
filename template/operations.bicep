@description('The friendly name for the workbook that is used in the Gallery or Saved List.  This name must be unique within a resource group.')
param workbookDisplayName string = 'AzStorageQuotaWorkbook'

@description('The gallery that the workbook will been shown under. Supported values include workbook, tsg, etc. Usually, this is \'workbook\'')
param workbookType string = 'workbook'

@description('The id of resource instance to which the workbook will be associated')
param workbookSourceId string = 'Azure Monitor'

@description('The unique guid for this workbook instance')
param workbookId string = newGuid()

@description('The storage SAS URL where the log file is stored for share stats')
param shareStatsStorageSas string = ''

@description('Log Analytics workspace associated with this workbook')
param laWorkspace string = ''

var workbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'let PFSstats = (externaldata (Resource:string, ShareStatsCollection:dynamic ) [@"${shareStatsStorageSas}"] with(format="multijson"));\r\n\r\nPFSstats\r\n| mv-expand ShareStatsCollection\r\n| extend FileShare = parse_json(ShareStatsCollection).FileShare, StorageAccount = parse_json(ShareStatsCollection).StorageAccount, SubscriptionId = parse_json(ShareStatsCollection).SubscriptionId, ResourceGroup = parse_json(ShareStatsCollection).ResourceGroup, Quota = parse_json(ShareStatsCollection).ProvisionedCapacity, UsedCapacity = parse_json(ShareStatsCollection).UsedCapacity, Autogrow = parse_json(ShareStatsCollection).TagAutogrow, AutogrowWatermark = parse_json(ShareStatsCollection).TagWatermark, AutogrowPercent = parse_json(ShareStatsCollection).quotagrowth\r\n| project FileShare, StorageAccount, SubscriptionId, ResourceGroup, Quota, UsedCapacity, Autogrow, AutogrowWatermark, AutogrowPercent\r\n| sort by tostring(FileShare) asc'
        size: 0
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        crossComponentResources: [
          laWorkspace
        ]
        gridSettings: {
          labelSettings: [
            {
              columnId: 'Quota'
              label: 'Quota GB'
            }
            {
              columnId: 'UsedCapacity'
              label: 'Used Capacity GB'
            }
            {
              columnId: 'Autogrow'
              label: 'Autogrow Enabled'
            }
            {
              columnId: 'AutogrowPercent'
              label: 'Autogrow %'
            }
          ]
        }
      }
      name: 'query - 0'
    }
  ]
  isLocked: false
  fallbackResourceIds: [
    'Azure Monitor'
  ]
}

resource workbookId_resource 'microsoft.insights/workbooks@2021-03-08' = {
  name: workbookId
  location: resourceGroup().location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: string(workbookContent)
    version: '1.0'
    sourceId: workbookSourceId
    category: workbookType
  }
  dependsOn: []
}

output workbookId string = workbookId_resource.id
