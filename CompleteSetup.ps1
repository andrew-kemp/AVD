# Function to check if a module is installed
function Install-ModuleIfNotInstalled {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Install-Module -Name $ModuleName -Scope CurrentUser -Force
    }
}

# Install necessary modules
Install-ModuleIfNotInstalled -ModuleName "Microsoft.Graph"
Install-ModuleIfNotInstalled -ModuleName "Az"
Install-ModuleIfNotInstalled -ModuleName "Az.DesktopVirtualization"

# Prompt for resource group
$resourceGroupName = Read-Host -Prompt "Enter the name of the resource group for your AVD hosts"

# Prompt for a prefix for all resources/groups (optional)
$prefix = Read-Host -Prompt "Enter a prefix for all group/device names (leave blank to use the resource group name)"
if ([string]::IsNullOrWhiteSpace($prefix)) {
    $prefix = $resourceGroupName
}

Write-Host "`nThe following naming will be used:"
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Prefix: $prefix"

# Prompt for group names (users, admins, devices) with defaults
$userGroupName = Read-Host -Prompt "Enter the user group name (default: _User-$prefix-Users)"
if ([string]::IsNullOrWhiteSpace($userGroupName)) {
    $userGroupName = "_User-$prefix-Users"
}
$adminGroupName = Read-Host -Prompt "Enter the admin group name (default: _User-$prefix-Admins)"
if ([string]::IsNullOrWhiteSpace($adminGroupName)) {
    $adminGroupName = "_User-$prefix-Admins"
}
$deviceGroupName = Read-Host -Prompt "Enter the device group name (default: _Device-$prefix)"
if ([string]::IsNullOrWhiteSpace($deviceGroupName)) {
    $deviceGroupName = "_Device-$prefix"
}

# Prompt for mail nicknames
$userMailNickname = Read-Host -Prompt "Mail nickname for user group (default: user${prefix}users)"
if ([string]::IsNullOrWhiteSpace($userMailNickname)) {
    $userMailNickname = "user${prefix}users"
}
$adminMailNickname = Read-Host -Prompt "Mail nickname for admin group (default: user${prefix}admins)"
if ([string]::IsNullOrWhiteSpace($adminMailNickname)) {
    $adminMailNickname = "user${prefix}admins"
}
$deviceMailNickname = Read-Host -Prompt "Mail nickname for device group (default: devices${prefix})"
if ([string]::IsNullOrWhiteSpace($deviceMailNickname)) {
    $deviceMailNickname = "devices${prefix}"
}

# Prompt for Application Group name
$appGroupName = Read-Host -Prompt "Enter the Application Group name (default: ${prefix}-AppGroup)"
if ([string]::IsNullOrWhiteSpace($appGroupName)) {
    $appGroupName = "${prefix}-AppGroup"
}

# Confirm summary
Write-Host "`nSummary of your choices:"
Write-Host "Resource group: $resourceGroupName"
Write-Host "Prefix: $prefix"
Write-Host "User group: $userGroupName (MailNickname: $userMailNickname)"
Write-Host "Admin group: $adminGroupName (MailNickname: $adminMailNickname)"
Write-Host "Device group: $deviceGroupName (MailNickname: $deviceMailNickname)"
Write-Host "Application Group: $appGroupName"
$proceed = Read-Host "Proceed with these settings? (Y/N)"
if ($proceed -notin @('Y', 'y')) {
    Write-Host "Exiting."
    exit
}

# Connect to Microsoft Graph and Azure
Connect-MgGraph -Scopes "Directory.ReadWrite.All", "Device.ReadWrite.All"
Connect-AzAccount

# Create AVD Users group
$userGroup = New-MgGroup -DisplayName $userGroupName -MailEnabled:$false -SecurityEnabled:$true -MailNickname $userMailNickname

# Create AVD Admins group
$adminGroup = New-MgGroup -DisplayName $adminGroupName -MailEnabled:$false -SecurityEnabled:$true -MailNickname $adminMailNickname

# Create Dynamic Device group
$groupBody = @{
    displayName = "$deviceGroupName"
    mailEnabled = $false
    mailNickname = $deviceMailNickname
    securityEnabled = $true
    groupTypes = @("DynamicMembership")
    membershipRule = "(device.displayName -startsWith `"$prefix`")"
    membershipRuleProcessingState = "On"
}
$group = New-MgGroup -BodyParameter $groupBody
Write-Output "Device group created with ID: $($group.Id)"

# Set extension attributes for devices
$params = @{
    extensionAttributes = @{
        extensionAttribute1 = "cloud Privileged Access Workstation"
    }
}
$devices = Get-MgDevice -Filter "startswith(displayName,'$prefix')"
foreach ($device in $devices) {
    Update-MgDevice -DeviceId $device.Id -BodyParameter $params
}

# List and select subscription
$subscriptions = Get-AzSubscription
for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    Write-Host "$i. $($subscriptions[$i].Name) - $($subscriptions[$i].Id)"
}
$subscriptionNumber = Read-Host -Prompt "Enter the number of the subscription from the list above"
$selectedSubscription = $subscriptions[$subscriptionNumber]
$subscriptionId = $selectedSubscription.Id
Set-AzContext -SubscriptionId $subscriptionId

# VM auto-shutdown
$vms = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object { $_.Name -like "$prefix*" }
foreach ($vm in $vms) {
    $vmName = $vm.Name
    Write-Output "Setting auto-shutdown for VM: $vmName"
    az vm auto-shutdown --resource-group $resourceGroupName --name $vmName --time 18:00 
}

# Role assignments
New-AzRoleAssignment -ObjectId $userGroup.Id -RoleDefinitionName "Virtual Machine User Login" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"
New-AzRoleAssignment -ObjectId $adminGroup.Id -RoleDefinitionName "Virtual Machine User Login" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"
New-AzRoleAssignment -ObjectId $adminGroup.Id -RoleDefinitionName "Virtual Machine Administrator Login" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

# Azure Virtual Desktop SPN
$avdServicePrincipal = Get-AzADServicePrincipal -DisplayName "Azure Virtual Desktop"
$avdServicePrincipalId = $avdServicePrincipal.Id
New-AzRoleAssignment -ObjectId $avdServicePrincipalId -RoleDefinitionName "Desktop Virtualization Power On Contributor" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

# Check for existence of the Application Group
$appGroup = Get-AzWvdApplicationGroup -Name $appGroupName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $appGroup) {
    Write-Host "Application Group '$appGroupName' does not exist in resource group '$resourceGroupName'."
    Write-Host "Please create it in the Azure Portal or with PowerShell before running the rest of this script."
    exit 1
}
$appGroupPath = $appGroup.Id

# Application Group Role assignment and Desktop renaming
$userGroupId = (Get-AzADGroup -DisplayName $userGroupName).Id
$adminGroupId = (Get-AzADGroup -DisplayName $adminGroupName).Id
New-AzRoleAssignment -ObjectId $userGroupId -RoleDefinitionName "Desktop Virtualization User" -Scope $appGroupPath
New-AzRoleAssignment -ObjectId $adminGroupId -RoleDefinitionName "Desktop Virtualization User" -Scope $appGroupPath

# Rename Session Desktop
$sessionDesktop = Get-AzWvdDesktop -ResourceGroupName $resourceGroupName -ApplicationGroupName $appGroupName -Name "SessionDesktop"
Update-AzWvdDesktop -ResourceGroupName $resourceGroupName -ApplicationGroupName $appGroupName -Name "SessionDesktop" -FriendlyName "Privileged Access Desktop"