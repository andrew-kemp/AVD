// Parameters
param sessionHostPrefix string = 'AVD'
param numberOfHosts int = 2

@secure()
param adminPassword string

param adminUsername string = 'AVD-Admin'
param hostPoolRegistrationInfoToken string = 'Enter HostPool Registration Key here'

// These values are for the existing vNet/subnet
param vNetResourceGroup string = 'Core-Services'
param vNetName string = 'Master-vNet'
param subnetName string = 'AzureVirtualDesktop'

// Parameter for the SessionHostPrep script URL
@description('URL of the SessionHostPrep.ps1 script')
param sessionHostPrepScriptUrl string = 'https://raw.githubusercontent.com/andrew-kemp/CloudPAW/refs/heads/main/SessionHostPrep.ps1'

var modulesURL = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_1.0.02797.442.zip'

// Reference the HostPool
resource HostPool 'Microsoft.DesktopVirtualization/hostpools@2021-07-12' existing = {
  name: '${sessionHostPrefix}-HostPool'
}

// Reference the existing subnet
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: '${vNetName}/${subnetName}'
  scope: resourceGroup(vNetResourceGroup)
}

// Create the NICs for the VMs
resource nic 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, numberOfHosts): {
  name: '${sessionHostPrefix}-${i}-nic'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: existingSubnet.id
          }
        }
      }
    ]
  }
}]

// Create the VMs
resource VM 'Microsoft.Compute/virtualMachines@2020-12-01' = [for i in range(0, numberOfHosts): {
  name: '${sessionHostPrefix}-${i}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_d2as_v5'
    }
    osProfile: {
      computerName: '${sessionHostPrefix}-${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: 'win11-24h2-avd'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 256
      }
      dataDisks: [
        {
          lun: 0
          createOption: 'Empty'
          diskSizeGB: 256
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic[i].id
        }
      ]
    }
  }
}]

// Join the VMs to Entra and Enroll in Intune
resource entraIdJoin 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = [for i in range(0, numberOfHosts): {
  parent: VM[i]
  name: '${sessionHostPrefix}-${i}-EntraJoinEntrollIntune'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.2'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    settings: {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } 
  }
}]

// Install the Guest Attestation Extension
resource guestAttestationExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for i in range(0, numberOfHosts): {
  parent: VM[i]
  name: '${sessionHostPrefix}-${i}-guestAttestationExtension'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Azure.Security.WindowsAttestation'
    type: 'GuestAttestation'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
  dependsOn:[
    entraIdJoin
  ]
}]

// Run some preparation on the VMs to remove any windows apps and also enable cloud kerberos
resource SessionPrep 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, numberOfHosts): {
  parent: VM[i]
  name: '${sessionHostPrefix}-${i}-SessionPrep'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        sessionHostPrepScriptUrl
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File SessionHostPrep.ps1'
    }
  }
  dependsOn: [
    guestAttestationExtension
  ]
}]

// Join the SessionHosts to the HostPool
resource dcs 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for i in range(0, numberOfHosts): {
  parent: VM[i]
  name: '${sessionHostPrefix}-${i}-JointoHostPool'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.76'
    settings: {
      modulesUrl: modulesURL
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: HostPool.name
        aadJoin: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: hostPoolRegistrationInfoToken
      }
    }
  }
  dependsOn: [
    SessionPrep
  ]
}]
