# Az File Share Quota Manager

A simple way to use Azure functions to automatically manage quota increase for Azure Premium file shares

## Problem

Many organisations are migrating Petabytes of data to the cloud often in the form of SMB and NFS shares to reduce infrastructure costs and management overhead. Azure storage has an array of SKUs to meet the cost and performance requirements of most organisations. The main difference between standard and premium storage is that standard storage incurs a cost for what is used and the transactions to write, read, delete,etc that data. With Azure Storage Files Premium there are no transaction costs (included) and a customer provisions the amount of storage required as per the share size and performance needs. Performance information (IOPS, bursting and throughput) can be found here.

One issue customers find is that there is no magic checkbox that enables autogrowth of a provisioned file share. Therefore the limits of a file share size can be reached without warning to the user/system or administrator which can disrupt business applications and create friction within an organisation. This repository mitigates this by providing a scheduled task that can check current usage of all shares that have a specific Azure Tag, if the share is within the tolerance then the share is programmatically increased.

Note\* - This is not a problem for Standard Storage Files since the size of the configured file share size does not incur any cost as it is the actual usage you are charged for. Therefore with Standard Storage Files you can set your file share to the highest possible size and you won't reach size limits or pay for this upper limit.

The following Azure technologies are used in this solution:
• Azure Functions (Powershell)
• Azure Files Premium (Azure Storage)
• Azure Storage Queue
• Azure Managed Service Identity

The default configuration will search for Premium Azure File shares that have the following Azure Tags:
• Autogrow - true or false.
• Watermark - integer number representing the percentage threshold for triggering the quota growth e.g. a value of 80 will mean the file share quota will be increased if the share usage is greater than 80% of the provisioned capacity.
• Quotagrowth - an integer number representing the percentage growth to increase the share by e.g. 15 will increase the file share quota by 15%.

# Enhancements

    • Enable searching for all storage accounts under Management Group(s)

Alert and approve when a share needs to be increased

# How to deploy

Detailed steps to follow

Deploy Azure Files Premium Storage account and create a file share
Create a storage queue in dedicated Storage account
Deploy Azure Functions (Powershell Core)
