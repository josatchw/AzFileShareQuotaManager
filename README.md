# Az File Share Quota Manager

A simple way to use Azure functions to automatically manage quota increase for Azure Premium file shares

## Problem

Many organisations are migrating Petabytes of data to the cloud often in the form of SMB and NFS shares to reduce infrastructure costs and management overhead. Azure storage has an array of SKUs to meet the cost and performance requirements of most organisations. The main difference between standard and premium storage is that standard storage incurs a cost for what is used and the transactions to write, read, delete,etc that data. With Azure Storage Files Premium there are no transaction costs (included) and a customer provisions the amount of storage required as per the share size and performance needs. Performance information (IOPS, bursting and throughput) can be found here.
https://docs.microsoft.com/en-us/azure/storage/files/understanding-billing

One issue customers find is that there is no magic checkbox that enables autogrowth of a provisioned file share. Therefore the limits of a file share size can be reached without warning to the user/system or administrator which can disrupt business applications and create friction within an organisation. This repository mitigates this by providing a scheduled task that can check current usage of all shares that have a specific Azure Tag, if the share is within the tolerance then the share is programmatically increased.

Note\* - This is not a problem for Standard Storage Files since the size of the configured file share size does not incur any cost as it is the actual usage you are charged for. Therefore with Standard Storage Files you can set your file share to the highest possible size and you won't reach size limits or pay for this upper limit.

The following Azure technologies are used in this solution:

- Azure Functions (Powershell)
- Azure Files Premium (Azure Storage)
- Azure Storage Queue
- Azure Managed Service Identity

The default configuration will search for Premium Azure File shares that have the following Azure Tags:

- autogrow - true or false.
- watermark - integer number representing the percentage threshold for triggering the quota growth e.g. a value of 15 will mean the file share quota will be increased if the share usage has less than 15% of the provisioned capacity left.
- quotagrowth - an integer number representing the percentage growth to increase the share by e.g. 15 will increase the file share quota by 15%.

The 'checkfsquota' function will check within the target subscription for all storage accounts marked as 'true' for the 'autogrow' tag. Then all fileshares in that account will be checked if the quota needs to be increased. If a quota threshold is within the watermark then a message is placed on the Azure storage Queue. The 'increasefsquota' function is triggered from the queue and reads the storage account and share details in order to process the quota increase.

# How to deploy

Detailed steps still in progress. For now

- Deploy the bicep template from the templates folder. The artefacts will all be deployed to one resource group.

  - Azure Files Premium Storage account to host a test file share
  - Storage account to host the queue - this is used by the Azure Functions. Record the Connection string of the storage account
  - Azure App Service (Plan) and Function App configured to Powershell. Also includes storage for the app and app insights. Configure the Function app to use a Managed Service Identity and provide that Identity Reader to the Subscription and Resource Group Contributor.
  - Set the Funtion App Setting (Portal > Function > Configuration) 'outputMessageQueue_STORAGE' to be the Storage Queue connection string. The checkfsquota function will write to this queue and the increasefsquota function will read from it.
  - Set the 'targetSubscriptionId' app setting to be your Sub Id you used to deploy the template.

- Deploy the Azure Functions (Powershell Core) code to the Azure Function App. You can copy the code in to the functions in the Azure Portal or use the VSCode function extension (Reference below).

# Enhancements

    • Enable searching for all storage accounts under Management Group(s)
    • Alert and approve when a share needs to be increased

# resources

- Azure storage templates - https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/2021-06-01/storageaccounts?tabs=bicep
- VSCode Azure function extenstion - https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell?tabs=portal
