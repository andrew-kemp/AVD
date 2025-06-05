@description('The name of the storage account.')
param storageAccountName string

@description('The Active Directory domain name for Azure AD Kerberos authentication (e.g., corp.contoso.com).')
param kerberosDomainName string

@description('The GUID of the Active Directory domain (e.g., 12345678-90ab-cdef-1234-567890abcdef).')
param kerberosDomainGuid string

@description('The Object ID of the group to assign Storage File Data SMB Share Contributor.')
param smbShareContributorGroupOid string

@description('The Object ID of the group to assign Storage File Data SMB Share Elevated Contributor.')
param smbShareElevatedContributorGroupOid string

@description('Resource group of the vNet for the Private Endpoint')
param vnetResourceGroup string = 'Core-Services'

@description('Name of the vNet for the Private Endpoint')
param vnetName string = 'Master-vNet'

@description('Subnet name for the Private Endpoint')
param subnetName string = 'Storage'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
      activeDirectoryProperties: {
        domainName: kerberosDomainName
        domainGuid: kerberosDomainGuid
      }
      // This enables share-level permissions for all authenticated users and groups
      sharePermissions: 'Share'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

resource fileShareProfiles 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: 'profiles'
  parent: fileService
}

resource fileShareRedirection 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: 'redirections'
  parent: fileService
}

// Role assignment for Storage File Data SMB Share Contributor (using correct ID for your subscription)
resource smbShareContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, smbShareContributorGroupOid, 'FileShareContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb')
    principalId: smbShareContributorGroupOid
    principalType: 'Group'
  }
}

// Role assignment for Storage File Data SMB Share Elevated Contributor (using correct ID for your subscription)
resource smbShareElevatedContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, smbShareElevatedContributorGroupOid, 'FileShareElevatedContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a7264617-510b-434b-a828-9731dc254ea7')
    principalId: smbShareElevatedContributorGroupOid
    principalType: 'Group'
  }
}

// Reference the vNet and subnet in another resource group
resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = {
  parent: vnet
  name: subnetName
}

// Private Endpoint for Storage Account File Service only (target subresource is 'file')
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${storageAccountName}-file-pe'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'storageAccountFileConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

output storageAccountId string = storageAccount.id
output profilesShareName string = fileShareProfiles.name
output redirectionShareName string = fileShareRedirection.name
output privateEndpointId string = privateEndpoint.id
