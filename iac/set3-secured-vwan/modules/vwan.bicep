targetScope = 'resourceGroup'

param parLocation string
param parHubAddressPrefix string

resource resVwan 'Microsoft.Network/virtualWans@2024-01-01' = {
  name: 'vwan-${parLocation}'
  location: parLocation
  properties: {
    type: 'Standard'
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
  }
}

resource resVhub 'Microsoft.Network/virtualHubs@2024-01-01' = {
  name: 'vhub-${parLocation}'
  location: parLocation
  properties: {
    virtualWan: { id: resVwan.id }
    addressPrefix: parHubAddressPrefix
    sku: 'Standard'
  }
}

output vwanId string = resVwan.id
output hubId string = resVhub.id
output hubName string = resVhub.name
