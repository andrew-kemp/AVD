#CLoud Kerberos
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
New-ItemProperty -Path $RegPath -Name "CloudKerberosTicketRetrievalEnabled" -Value 1 -PropertyType DWord
#FSLogix Config
# Define the parent registry path for FSLogix
$ParentPath = "HKLM:\SOFTWARE\FSLogix"
# Define the full registry path for FSLogix Profiles
$RegPath = "$ParentPath\Profiles"
# Define the network locations for profile and redirection storage
$ProfilesPath = "\\kempystoragev1.file.core.windows.net\profiles"
$RedirectionPath = "\\kempystoragev1.file.core.windows.net\redirections"
# Check if the FSLogix registry parent key exists
if (-not (Test-Path $ParentPath)) {
    # If not, create the FSLogix registry key under HKLM:\SOFTWARE
    New-Item -Path "HKLM:\SOFTWARE" -Name "FSLogix" -Force | Out-Null
}
# Check if the Profiles registry key exists under FSLogix
if (-not (Test-Path $RegPath)) {
    # If not, create the Profiles subkey
    New-Item -Path $ParentPath -Name "Profiles" -Force | Out-Null
}
# Set the 'FlipFlopProfileDirectoryName' DWORD property to 1
New-ItemProperty -Path $RegPath -Name "FlipFlopProfileDirectoryName" -Value 1 -PropertyType DWord -Force
# Set the 'VolumeType' string property to 'VHDX'
New-ItemProperty -Path $RegPath -Name "VolumeType" -Value "VHDX" -PropertyType String -Force
# Set the 'VHDLocations' string property to the profiles path
New-ItemProperty -Path $RegPath -Name "VHDLocations" -Value $ProfilesPath -PropertyType String -Force
# Set the 'Enabled' DWORD property to 1 (enable FSLogix profiles)
New-ItemProperty -Path $RegPath -Name "Enabled" -Value 1 -PropertyType DWord -Force
# Set the 'DeleteLocalProfileWhenVHDShouldApply' DWORD property to 1
New-ItemProperty -Path $RegPath -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -PropertyType DWord -Force
# Set the 'RedirXMLSourceFolder' string property to the redirection path
New-ItemProperty -Path $RegPath -Name "RedirXMLSourceFolder" -Value $RedirectionPath -PropertyType String -Force

#Clean up Apps
$UWPAppstoRemove = @(
"Microsoft.BingNews",
"Microsoft.GamingApp",
"Microsoft.MicrosoftSolitaireCollection",
"Microsoft.WindowsCommunicationsApps",
"Microsoft.WindowsFeedbackHub",
"Microsoft.XboxGameOverlay",
"Microsoft.XboxGamingOverlay",
"Microsoft.XboxIdentityProvider",
"Microsoft.XboxSpeechToTextOverlay",
"Microsoft.YourPhone",
"Microsoft.ZuneMusic",
"Microsoft.ZuneVideo",
"MicrosoftTeams",
"Microsoft.OutlookForWindows",
"Microsoft.Windows.DevHome",
"Microsoft.MicrosoftOfficeHub",
"Microsoft.MicrosoftStickyNotes",
"Microsoft.People",
"Microsoft.ScreenSketch",
"microsoft.windowscommunicationsapps",
"Microsoft.WindowsFeedbackHub",
"Microsoft.WindowsMaps"
"Microsoft.WindowsSoundRecorder"
"Microsoft.Xbox.TCUI"
"Microsoft.Windows.AugLoop.CBS"
"Microsoft.Windows.CapturePicker"
"Microsoft.Windows.NarratorQuickStart"
"Microsoft.Windows.ParentalControls"
"Microsoft.Windows.PeopleExperienceHost"
"Microsoft.Windows.PinningConfirmationDialog"
"Microsoft.Windows.PrintQueueActionCenter"
"Microsoft.Windows.StartMenuExperienceHost"
"Microsoft.Windows.XGpuEjectDialog"
"Microsoft.WindowsAppRuntime.CBS.1.6"
"Microsoft.WindowsAppRuntime.CBS"
"Microsoft.XboxGameCallableUI"
"Windows.CBSPreview"
"Clipchamp.Clipchamp"
"Microsoft.BingSearch"
"Microsoft.BingWeather"
"Microsoft.GetHelp"
"Microsoft.MicrosoftOfficeHub"
"Microsoft.MicrosoftStickyNotes"
"Microsoft.OutlookForWindows"
"Microsoft.Paint"
"Microsoft.PowerAutomateDesktop"
"Microsoft.RawImageExtension"
"Microsoft.ScreenSketch"
"Microsoft.StorePurchaseApp"
"Microsoft.Todos"
"Microsoft.WebMediaExtensions"
"Microsoft.WebpImageExtension"
"Microsoft.Windows.DevHome"
"Microsoft.Windows.Photos"
"Microsoft.WindowsAlarms"
"Microsoft.WindowsCalculator"
"Microsoft.WindowsCamera"
"Microsoft.WindowsSoundRecorder"
"Microsoft.WindowsStore"
"Microsoft.Xbox.TCUI"
"MicrosoftCorporationII.QuickAssist"
"MSTeams"
"*Microsoft.Getstarted*"

)
# Remove preinstalled Microsoft Store applications for all users and from the Windows image
foreach ($UWPApp in $UWPAppstoRemove) {
Get-AppxPackage -Name $UWPApp -AllUsers | Remove-AppxPackage -AllUsers -verbose
Get-AppXProvisionedPackage -Online | Where-Object DisplayName -eq $UWPApp | Remove-AppxProvisionedPackage -Online -verbose
}
