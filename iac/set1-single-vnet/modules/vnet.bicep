targetScope = 'resourceGroup'

param parLocation string
param parAddressRange string
param parOnpremAddressRange string

var varVNetName = 'vnet-single-${parLocation}'
var varOnpremVNetName = 'vnet-onprem-${parLocation}'

module modSingleVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-${varVNetName}'
  params: {
    name: varVNetName
    location: parLocation
    addressPrefixes: [parAddressRange]
    subnets: [
      {
        name: 'subnet-inbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 0)]
      }
      {
        name: 'subnet-outbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 1)]
      }
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
        remotePeeringName: 'single-to-onprem'
        remoteVirtualNetworkResourceId: modSingleVNet.outputs.resourceId
        useRemoteGateways: false
      }
    ]
    enableTelemetry: false
  }
}

output singleVnetId string = modSingleVNet.outputs.resourceId
output inboundSubnetId string = modSingleVNet.outputs.subnetResourceIds[0]
output outboundSubnetId string = modSingleVNet.outputs.subnetResourceIds[1]
output bastionSubnetId string = modSingleVNet.outputs.subnetResourceIds[2]
output workloadSubnetId string = modSingleVNet.outputs.subnetResourceIds[3]
output peSubnetId string = modSingleVNet.outputs.subnetResourceIds[4]
output onpremVnetId string = modOnpremVNet.outputs.resourceId
output onpremSubnetId string = modOnpremVNet.outputs.subnetResourceIds[0]
