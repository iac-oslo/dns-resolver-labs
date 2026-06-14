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
        name: 'AzureFirewallSubnet'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 0)]
      }
      {
        name: 'AzureFirewallManagementSubnet'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 1)]
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefixes: [cidrSubnet(parAddressRange, 26, 2)]
      }
      {
        name: 'subnet-inbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 12)]
      }
      {
        name: 'subnet-outbound'
        addressPrefixes: [cidrSubnet(parAddressRange, 28, 13)]
      }
      {
        name: 'subnet-pe'
        addressPrefixes: [cidrSubnet(parAddressRange, 27, 8)]
      }
    ]
    enableTelemetry: false
  }
}

output hubVnetId string = modHubVNet.outputs.resourceId
output firewallSubnetId string = modHubVNet.outputs.subnetResourceIds[0]
output firewallMgmtSubnetId string = modHubVNet.outputs.subnetResourceIds[1]
output bastionSubnetId string = modHubVNet.outputs.subnetResourceIds[2]
output inboundSubnetId string = modHubVNet.outputs.subnetResourceIds[3]
output outboundSubnetId string = modHubVNet.outputs.subnetResourceIds[4]
output peSubnetId string = modHubVNet.outputs.subnetResourceIds[5]
