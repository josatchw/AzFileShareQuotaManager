using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "Testing for PowerShell Modules..."

[System.Collections.ArrayList]$messages = @()

for ($num = 1 ; $num -le 10 ; $num++) {    
    
    $message = @{
        SubscriptionId      = "12312312312312"
        ResourceGroup       = "RG $num"
        FileShare           = "testshare $num"
        StorageAccount      = "accountname12345"
        ProvisionedCapacity = "100"
        quotagrowth         = "20"
        UsedCapacity        = "15"
        TagAutogrow         = "true"
        TagWatermark        = "10"
        TagQuotagrowth      = "15"
    }

    $messages.Add($message)
}


$Time = Get-Date
$Time.ToUniversalTime()

$shareStats = [PSCustomObject]@{
    StatsDate            = $Time.ToUniversalTime()
    SubscriptionId       = "12312312312312"
    ShareStatsCollection = $messages
}
Push-OutputBinding -Name shareStatsBlob -Value $shareStats | ConvertTo-Json
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $(Get-Module -ListAvailable | Select-Object Name, Path)
    })
