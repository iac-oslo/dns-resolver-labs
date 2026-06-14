targetScope = 'subscription'

param parLocation string

import { getResourcePrefix, hubAddressRange, onpremAddressRange, adminUsername, adminPassword } from 'variables.bicep'

var varResourcePrefix = getResourcePrefix(parLocation)
var varResourceGroupName = 'rg-${varResourcePrefix}-s2'

module rg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: 'deploy-${varResourceGroupName}'
  params: {
    name: varResourceGroupName
    location: parLocation
  }
}

module hub 'modules/hub.bicep' = {
  name: 'deploy-hub-s2'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parAddressRange: hubAddressRange
  }
}

module spokes 'modules/spoke.bicep' = [for i in range(1, 2): {
  name: 'deploy-spoke${i}-s2'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parIndex: i
    parLocation: parLocation
    parAddressRange: '10.11.${i}.0/24'
    parHubVnetId: hub.outputs.hubVnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}]

module onprem 'modules/onprem.bicep' = {
  name: 'deploy-onprem-s2'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parAddressRange: onpremAddressRange
    parHubVnetId: hub.outputs.hubVnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

module resolver 'modules/resolver.bicep' = {
  name: 'deploy-resolver-s2'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: hub.outputs.hubVnetId
    parInboundSubnetId: hub.outputs.inboundSubnetId
    parOutboundSubnetId: hub.outputs.outboundSubnetId
  }
}

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage-s2'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parHubVnetId: hub.outputs.hubVnetId
    parPeSubnetId: hub.outputs.peSubnetId
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'deploy-bastion-s2'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: hub.outputs.hubVnetId
  }
}
