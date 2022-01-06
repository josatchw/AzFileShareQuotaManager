bicep build ./main.bicep # generates main.json

$resourceGroup = 'AzFileShareQuotaManager'
$location = 'australiaeast'

# optional step if resource group already exists
New-AzResourceGroup -Name $resourceGroup -Location $location


New-AzResourceGroupDeployment -TemplateFile main.json -ResourceGroupName $resourceGroup
