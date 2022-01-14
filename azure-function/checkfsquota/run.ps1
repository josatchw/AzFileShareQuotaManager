using namespace System.Net
# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

$subscription_id = $env:targetSubscriptionId
$tag_autogrow = $env:tag_autogrow
$tag_watermark = $env:tag_watermark
$tag_quotagrowth = $env:tag_quotagrowth

# Write an information log 
Write-Host "Checking File Storage in Subscription scope: $subscription_id"

$query = "Resources | where kind =~ 'FileStorage' | where tags['$($tag_autogrow)']=='true' | project name, tags, resourceGroup"
$azgraphResponse = Search-AzGraph -Query $query
Write-Host $azgraphResponse.Data
$storageAccounts = $azgraphResponse.Data

Write-Host "Number of STORAGE ACCOUNTS found: $($storageAccounts.Count)" 
[System.Collections.ArrayList]$shareStatsCollection = @()

foreach ($storageAccount in $storageAccounts) {
    $tagobj = Get-AzStorageAccount -ResourceGroupName $storageAccount.resourceGroup -Name $storageAccount.name | Select-Object tags
    $storageAccountName = $storageAccount.name
    $watermark = $tagobj.Tags.$tag_watermark
    $quotagrowth = $tagobj.Tags.$tag_quotagrowth
    Write-Host "Storage account: $($storageAccountName) - Watermark: $($watermark)%, Quotagrowth: $($quotagrowth)%" 
    $shares = Get-AzRmStorageShare -ResourceGroupName $storageAccount.resourceGroup -StorageAccountName $storageAccount.name -GetShareUsage

    foreach ($share in $shares) {
        $shareDetail = Get-AzRmStorageShare -ResourceGroupName $storageAccount.resourceGroup -StorageAccountName $storageAccount.name -Name $share.Name -GetShareUsage
        $ProvisionedCapacity = $share.QuotaGiB
        $UsedCapacityBytes = $shareDetail.ShareUsageBytes
        Write-Host "Premium File Storage Share quota: $($share.Name): $($share.QuotaGiB)GB - Used capacity: $UsedCapacityBytes"

        $usedCapacity = ($UsedCapacityBytes / ([Math]::Pow(2, 30)))
        # remaining capacity in GB (with convert usedCapacity bytes to GB). Capacity in bytes can also be converted to GB: [math]::round($byteValue /1Gb, 3)
        $remainingCapacity = ($ProvisionedCapacity - $usedCapacity)
                
        $message = @{
            SubscriptionId      = $subscription_id
            ResourceGroup       = $storageAccount.resourceGroup
            FileShare           = $share.Name 
            StorageAccount      = $storageAccount.name
            ProvisionedCapacity = $ProvisionedCapacity
            quotagrowth         = $quotagrowth
            RemainingCapacity   = $remainingCapacity
            UsedCapacity        = $usedCapacity
            TagAutogrow         = $tagobj.Tags.$tag_autogrow
            TagWatermark        = $tagobj.Tags.$tag_watermark
            TagQuotagrowth      = $tagobj.Tags.$tag_quotagrowth
        }
        # collate all stats 
        $shareStatsCollection.Add($message)
        
        # Write to the queue to if the remaining capacity is higher than the watermark level. When running locally always force a quota increase
        if ($usedCapacity -ge $watermark ) {

            Write-Host "Queing storageAccount quota increase request..."
            $jsonMessage = $message | ConvertTo-Json
            Write-Host $jsonMessage
            Push-OutputBinding -Name expandfsquota -Value $jsonMessage.ToString()
    
        }
        else {
            $message = "Storage Share: $($share.Name) - Remaining capacity sufficient: $([math]::round($remainingCapacity,2))GB" 
            Write-Host $message
        }
        
    }
    
}
# Write to shareStats log - this is a point in time snapshop of the share status 
$Time = Get-Date
$shareStats = [PSCustomObject]@{
    StatsDate            = $Time.ToUniversalTime()
    SubscriptionId       = $subscription_id
    ShareStatsCollection = $shareStatsCollection
} 
Push-OutputBinding -Name shareStatsBlob -Value $shareStats

# Write an information log with the current time.
Write-Host "CHECKFSQUOTA timer trigger function ran! TIME: $currentUTCtime"


