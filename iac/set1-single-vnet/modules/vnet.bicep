targetScope = 'resourceGroup'

param parLocation string
param parAddressRange string
param parResolverAddressRange string
param parOnpremAddressRange string

var varWorkloadVNetName = 'vnet-workload-${parLocation}'
var varResolverVNetName = 'vnet-resolver-${parLocation}'
var varOnpremVNetName = 'vnet-onprem-${parLocation}'

module modResolverVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-${varResolverVNetName}'
  params: {
    name: varResolverVNetName
    location: parLocation
    addressPrefixes: [parResolverAddressRange]
    subnets: [
      {
        name: 'subnet-inbound'
        addressPrefixes: [cidrSubnet(parResolverAddressRange, 28, 0)]
        delegation: 'Microsoft.Network/dnsResolvers'
      }
      {
        name: 'subnet-outbound'
        addressPrefixes: [cidrSubnet(parResolverAddressRange, 28, 1)]
        delegation: 'Microsoft.Network/dnsResolvers'
      }
    ]
    peerings: [
      {
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: 'workload-to-resolver'
        remoteVirtualNetworkResourceId: modWorkloadVNet.outputs.resourceId
        useRemoteGateways: false
      }
      {
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: 'onprem-to-resolver'
        remoteVirtualNetworkResourceId: modOnpremVNet.outputs.resourceId
        useRemoteGateways: false
      }
    ]
    enableTelemetry: false
  }
}

module modWorkloadVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-${varWorkloadVNetName}'
  params: {
    name: varWorkloadVNetName
    location: parLocation
    addressPrefixes: [parAddressRange]
    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 1)]
      }
      {
        name: 'subnet-workload'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 2)]
      }
      {
        name: 'subnet-pe'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 3)]
      }
    ]
    enableTelemetry: false
  }
}

module modOnpremVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-${varOnpremVNetName}'
  params: {
    name: varOnpremVNetName
    location: parLocation
    addressPrefixes: [parOnpremAddressRange]
    subnets: [
      {
        name: 'subnet-onprem'
        addressPrefixes: [parOnpremAddressRange]
      }
    ]
    peerings: [
      {
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: 'workload-to-onprem'
        remoteVirtualNetworkResourceId: modWorkloadVNet.outputs.resourceId
        useRemoteGateways: false
      }
    ]
    enableTelemetry: false
  }
}

output resolverVnetId string = modResolverVNet.outputs.resourceId
output inboundSubnetId string = modResolverVNet.outputs.subnetResourceIds[0]
output outboundSubnetId string = modResolverVNet.outputs.subnetResourceIds[1]
output workloadVnetId string = modWorkloadVNet.outputs.resourceId
output bastionSubnetId string = modWorkloadVNet.outputs.subnetResourceIds[0]
output workloadSubnetId string = modWorkloadVNet.outputs.subnetResourceIds[1]
output peSubnetId string = modWorkloadVNet.outputs.subnetResourceIds[2]
output onpremVnetId string = modOnpremVNet.outputs.resourceId
output onpremSubnetId string = modOnpremVNet.outputs.subnetResourceIds[0]
