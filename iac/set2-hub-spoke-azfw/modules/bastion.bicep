targetScope = 'resourceGroup'

param parLocation string
param parVnetId string

module modPublicIP 'br/public:avm/res/network/public-ip-address:0.9.1' = {
  name: 'deploy-pip-bastion'
  params: {
    name: 'pip-bastion-${parLocation}'
    location: parLocation
    skuName: 'Standard'
    availabilityZones: []
    enableTelemetry: false
  }
}

resource resBastion 'Microsoft.Network/bastionHosts@2024-07-01' = {
  name: 'bastion-${parLocation}'
  location: parLocation
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConfAzureBastionSubnet'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: modPublicIP.outputs.resourceId
          }
          subnet: {
            id: '${parVnetId}/subnets/AzureBastionSubnet'
          }
        }
      }
    ]
  }
}
