targetScope = 'resourceGroup'

param parLocation string
param parAddressRange string
param parHubVnetId string
param adminUsername string
@secure()
param adminPassword string

module modOnpremVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-vnet-onprem-${parLocation}'
  params: {
    name: 'vnet-onprem-${parLocation}'
    location: parLocation
    addressPrefixes: [parAddressRange]
    subnets: [
      {
        name: 'subnet-onprem'
        addressPrefixes: [parAddressRange]
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
        remotePeeringName: 'hub-to-onprem'
        remoteVirtualNetworkResourceId: parHubVnetId
        useRemoteGateways: false
      }
    ]
    enableTelemetry: false
  }
}

module modOnpremVM 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'deploy-vm-onprem-${parLocation}'
  params: {
    name: 'vm-onprem-${parLocation}'
    location: parLocation
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      offer: '0001-com-ubuntu-server-jammy'
      publisher: 'Canonical'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: modOnpremVNet.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 30
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    extensionCustomScriptConfig: {
      settings: {
        fileUris: [
          'https://raw.githubusercontent.com/iac-oslo/dns-resolver-labs/main/iac/scripts/setup-onprem-dns.sh'
        ]
        commandToExecute: 'bash setup-onprem-dns.sh'
      }
    }
    osType: 'Linux'
    vmSize: 'Standard_B1s'
    availabilityZone: -1
    enableTelemetry: false
  }
}

output onpremVnetId string = modOnpremVNet.outputs.resourceId
