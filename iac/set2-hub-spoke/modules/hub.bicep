targetScope = 'resourceGroup'

param parLocation string
param parAddressRange string

var varVNetName = 'vnet-hub-${parLocation}'

module modHubVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-${varVNetName}'
  params: {
    name: varVNetName
    location: parLocation
    addressPrefixes: [parAddressRange]
    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 0)]
      }
      {
        name: 'subnet-inbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 4)]
      }
      {
        name: 'subnet-outbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 5)]
      }
      {
        name: 'subnet-pe'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 6)]
      }
      {
        name: 'subnet-workload'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 2)]
      }
    ]
    enableTelemetry: false
  }
}

output hubVnetId string = modHubVNet.outputs.resourceId
output bastionSubnetId string = modHubVNet.outputs.subnetResourceIds[0]
output inboundSubnetId string = modHubVNet.outputs.subnetResourceIds[1]
output outboundSubnetId string = modHubVNet.outputs.subnetResourceIds[2]
output peSubnetId string = modHubVNet.outputs.subnetResourceIds[3]
output workloadSubnetId string = modHubVNet.outputs.subnetResourceIds[4]
