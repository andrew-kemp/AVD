param DefaultPrefix string = 'Kemponline'


//Deploy the Hostpool
resource HostPool 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' = {
  name: '${DefaultPrefix}-HostPool'
  location: resourceGroup().location
  properties: {
    friendlyName: '${DefaultPrefix} Host Pool'
    description: '${DefaultPrefix} AVD Host Pool for users to securely access resources from'
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: 5
    personalDesktopAssignmentType: 'Automatic'
    startVMOnConnect: true
    preferredAppGroupType: 'Desktop'
    customRdpProperty: 'enablecredsspsupport:i:1;authentication level:i:2;enablerdsaadauth:i:1;redirectwebauthn:i:1;'
  }
}

//Deploy the vPAW Desktop Application Group
resource AppGroup 'Microsoft.DesktopVirtualization/applicationGroups@2021-07-12' = {
  name: '${DefaultPrefix}-AppGroup'
  location: resourceGroup().location
  properties: {
    description: '${DefaultPrefix} Application Group'
    friendlyName: '${DefaultPrefix} Desktop Application Group'
    hostPoolArmPath: HostPool.id
    applicationGroupType: 'Desktop'
  }
}

//Deploy the vPAW Workspace 
resource Workspace 'Microsoft.DesktopVirtualization/workspaces@2021-07-12' = {
  name: '${DefaultPrefix}-Workspace'
  location: resourceGroup().location
  properties: {
    description: '${DefaultPrefix} Workspace'
    friendlyName: '${DefaultPrefix} Workspace'
   applicationGroupReferences: [
    AppGroup.id
   ]
    
}
}
