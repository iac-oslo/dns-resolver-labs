targetScope = 'subscription'

param parLocation string

import {
  getResourcePrefix
  vwanHubAddressRange
  connectivityAddressRange
  spokeAddressRange
  onpremAddressRange
  adminUsername
  adminPassword
} from 'variables.bicep'

var varResourcePrefix = getResourcePrefix(parLocation)
var varResourceGroupName = 'rg-${varResourcePrefix}-s3'

module rg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: 'deploy-${varResourceGroupName}'
  params: {
    name: varResourceGroupName
    location: parLocation
  }
}

module vwan 'modules/vwan.bicep' = {
  name: 'deploy-vwan-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parHubAddressPrefix: vwanHubAddressRange
  }
}

module connectivity 'modules/connectivity.bicep' = {
  name: 'deploy-connectivity-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parAddressRange: connectivityAddressRange
  }
}

module resolver 'modules/resolver.bicep' = {
  name: 'deploy-resolver-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: connectivity.outputs.connectivityVnetId
    parInboundSubnetId: connectivity.outputs.inboundSubnetId
    parOutboundSubnetId: connectivity.outputs.outboundSubnetId
  }
}

module firewall 'modules/firewall.bicep' = {
  name: 'deploy-firewall-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parHubId: vwan.outputs.hubId
    parHubName: vwan.outputs.hubName
    parResolverInboundIP: resolver.outputs.inboundEndpointIP
    parAllCidrs: [connectivityAddressRange, spokeAddressRange, onpremAddressRange]
  }
}

module spoke 'modules/spoke.bicep' = {
  name: 'deploy-spoke-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parAddressRange: spokeAddressRange
    parFirewallIP: firewall.outputs.azfwPrivateIP
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

module onprem 'modules/onprem.bicep' = {
  name: 'deploy-onprem-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parAddressRange: onpremAddressRange
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'deploy-bastion-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: connectivity.outputs.connectivityVnetId
  }
}

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parConnectivityVnetId: connectivity.outputs.connectivityVnetId
    parPeSubnetId: connectivity.outputs.peSubnetId
  }
}

module connections 'modules/connections.bicep' = {
  name: 'deploy-connections-s3'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [firewall]
  params: {
    parHubId: vwan.outputs.hubId
    parHubName: vwan.outputs.hubName
    parConnectivityVnetId: connectivity.outputs.connectivityVnetId
    parSpokeVnetId: spoke.outputs.spokeVnetId
    parOnpremVnetId: onprem.outputs.onpremVnetId
  }
}
