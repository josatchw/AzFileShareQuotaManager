# Input bindings are passed in via param block.
param( $QueueItem, $TriggerMetadata)

$messageobj = $QueueItem

# Connect-AzAccount -Identity 
Import-Module -Name Az.Accounts
Import-Module -Name Az.Storage
Set-AzContext -SubscriptionId $messageobj.SubscriptionId

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $messageobj.ResourceGroup -AccountName $messageobj.StorageAccount

# attemtping to increase quota
$fileShare = $messageobj.FileShare
$Quota = $messageobj.ProvisionedCapacity
$newQuota = $Quota * (($messageobj.quotagrowth / 100) + 1)
Update-AzRmStorageShare -StorageAccount $StorageAccount -Name $messageobj.FileShare -QuotaGiB $newQuota

# Write out the queue message and insertion time to the information log.
Write-Host "FileShare: $fileShare, quota increased from $Quota Gb to $newQuota GB"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"
