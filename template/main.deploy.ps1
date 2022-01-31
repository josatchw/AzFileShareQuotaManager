# Simple file to quickly deploy templates in this solution
$resourceGroup = 'AzFileShareQuotaManager'
$location = 'australiaeast'

# optional step if resource group already exists
New-AzResourceGroup -Name $resourceGroup -Location $location

bicep build ./main.bicep # generates main.json
New-AzResourceGroupDeployment -TemplateFile main.json -ResourceGroupName $resourceGroup

bicep build ./operations.bicep # generates main.json
New-AzResourceGroupDeployment -TemplateFile operations.json -ResourceGroupName $resourceGroup -TemplateFile parameters.secret.json

