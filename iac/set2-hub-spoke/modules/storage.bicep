targetScope = 'resourceGroup'

param parLocation string
param parHubVnetId string
param parPeSubnetId string

module modPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.0' = {
  name: 'deploy-private-dns-zone-blob'
  params: {
    name: 'privatelink.blob.core.windows.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        name: 'link-hub-vnet'
        virtualNetworkResourceId: parHubVnetId
        registrationEnabled: false
      }
    ]
    enableTelemetry: false
  }
}

var varStorageAccountName = 'sa${take(uniqueString(resourceGroup().id), 18)}'

module modStorageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: 'deploy-storage-account'
  params: {
    name: varStorageAccountName
    location: parLocation
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    privateEndpoints: [
      {
        name: 'pe-blob-${parLocation}'
        subnetResourceId: parPeSubnetId
        service: 'blob'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: modPrivateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
    enableTelemetry: false
  }
}

output storageAccountName string = varStorageAccountName
output privateDnsZoneId string = modPrivateDnsZone.outputs.resourceId
