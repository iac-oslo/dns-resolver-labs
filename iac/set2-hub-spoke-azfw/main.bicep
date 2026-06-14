targetScope = 'subscription'

param parLocation string

import { getResourcePrefix, hubAddressRange, onpremAddressRange, adminUsername, adminPassword } from 'variables.bicep'

var varResourcePrefix = getResourcePrefix(parLocation)
var varResourceGroupName = 'rg-${varResourcePrefix}-s2'
var varSpoke1Cidr = '10.12.2.0/24'
var varSpoke2Cidr = '10.12.3.0/24'
var varSpokeCidrs = [varSpoke1Cidr, varSpoke2Cidr]

module rg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: 'deploy-${varResourceGroupName}'
  params: {
    name: varResourceGroupName
    location: parLocation
  }
}

module hub 'modules/hub.bicep' = {
  name: 'deploy-hub-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parAddressRange: hubAddressRange
  }
}

module resolver 'modules/resolver.bicep' = {
  name: 'deploy-resolver-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: hub.outputs.hubVnetId
    parInboundSubnetId: hub.outputs.inboundSubnetId
    parOutboundSubnetId: hub.outputs.outboundSubnetId
  }
}

module firewall 'modules/firewall.bicep' = {
  name: 'deploy-firewall-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parHubVnetId: hub.outputs.hubVnetId
    parResolverInboundIP: resolver.outputs.inboundEndpointIP
    parSpokeCidrs: varSpokeCidrs
  }
}

module spokes 'modules/spoke.bicep' = [for i in range(1, 2): {
  name: 'deploy-spoke${i}-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parIndex: i
    parLocation: parLocation
    parAddressRange: '10.12.${i + 1}.0/24'
    parHubVnetId: hub.outputs.hubVnetId
    parFirewallIP: firewall.outputs.firewallPrivateIP
    parRemoteSpokeCidrs: [i == 1 ? varSpoke2Cidr : varSpoke1Cidr]
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}]

module onprem 'modules/onprem.bicep' = {
  name: 'deploy-onprem-s3'
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

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parHubVnetId: hub.outputs.hubVnetId
    parPeSubnetId: hub.outputs.peSubnetId
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'deploy-bastion-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: hub.outputs.hubVnetId
  }
}
