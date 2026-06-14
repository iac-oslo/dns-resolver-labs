targetScope = 'resourceGroup'

param parLocation string
param parIndex int
param parAddressRange string
param parHubVnetId string
param adminUsername string
@secure()
param adminPassword string

var varVNetName = 'vnet-spoke${parIndex}-${parLocation}'

module modSpokeVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-${varVNetName}'
  params: {
    name: varVNetName
    location: parLocation
    addressPrefixes: [parAddressRange]
    subnets: [
      {
        name: 'subnet-workload'
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
        remotePeeringName: 'hub-to-spoke${parIndex}'
        remoteVirtualNetworkResourceId: parHubVnetId
        useRemoteGateways: false
      }
    ]
    enableTelemetry: false
  }
}

module modSpokeVM 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'deploy-vm-spoke${parIndex}-${parLocation}'
  params: {
    name: 'vm-spoke${parIndex}-${parLocation}'
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
            subnetResourceId: modSpokeVNet.outputs.subnetResourceIds[0]
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
          'https://raw.githubusercontent.com/iac-oslo/dns-resolver-labs/refs/heads/main/iac/scripts/setup-workload.sh'
        ]
        commandToExecute: 'bash setup-workload.sh'
      }
    }
    osType: 'Linux'
    vmSize: 'Standard_B1s'
    availabilityZone: -1
    enableTelemetry: false
  }
}

output spokeVnetId string = modSpokeVNet.outputs.resourceId
