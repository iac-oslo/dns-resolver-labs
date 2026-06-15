targetScope = 'resourceGroup'

param parLocation string
param parAddressRange string

module modConnectivityVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-vnet-connectivity-${parLocation}'
  params: {
    name: 'vnet-connectivity-${parLocation}'
    location: parLocation
    addressPrefixes: [parAddressRange]
    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 0)]
      }
      {
        name: 'subnet-inbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 8)]
      }
      {
        name: 'subnet-outbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 9)]
      }
      {
        name: 'subnet-pe'
        addressPrefixes: [cidrSubnet(parAddressRange, 27, 6)]
      }
    ]
    enableTelemetry: false
  }
}

output connectivityVnetId string = modConnectivityVNet.outputs.resourceId
output bastionSubnetId string = modConnectivityVNet.outputs.subnetResourceIds[0]
output inboundSubnetId string = modConnectivityVNet.outputs.subnetResourceIds[1]
output outboundSubnetId string = modConnectivityVNet.outputs.subnetResourceIds[2]
output peSubnetId string = modConnectivityVNet.outputs.subnetResourceIds[3]
