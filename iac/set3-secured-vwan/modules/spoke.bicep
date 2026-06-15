targetScope = 'resourceGroup'

param parLocation string
param parAddressRange string
param parFirewallIP string
param adminUsername string
@secure()
param adminPassword string

module modSpokeVNet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'deploy-vnet-spoke-${parLocation}'
  params: {
    name: 'vnet-spoke-${parLocation}'
    location: parLocation
    addressPrefixes: [parAddressRange]
    dnsServers: [parFirewallIP]
    subnets: [
      {
        name: 'subnet-workload'
        addressPrefixes: [parAddressRange]
      }
    ]
    enableTelemetry: false
  }
}

module modSpokeVM 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'deploy-vm-spoke-${parLocation}'
  params: {
    name: 'vm-spoke-${parLocation}'
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
          'https://raw.githubusercontent.com/iac-oslo/dns-resolver-labs/main/iac/scripts/setup-workload.sh'
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
