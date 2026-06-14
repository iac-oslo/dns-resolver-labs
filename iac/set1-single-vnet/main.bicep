targetScope = 'subscription'

param parLocation string

import { getResourcePrefix, singleVnetAddressRange, resolverVnetAddressRange, onpremVnetAddressRange, adminUsername, adminPassword } from 'variables.bicep'

var varResourcePrefix = getResourcePrefix(parLocation)
var varResourceGroupName = 'rg-${varResourcePrefix}-s1'

module rg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: 'deploy-${varResourceGroupName}'
  params: {
    name: varResourceGroupName
    location: parLocation
  }
}

module vnet 'modules/vnet.bicep' = {
  name: 'deploy-vnets-s1'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parAddressRange: singleVnetAddressRange
    parResolverAddressRange: resolverVnetAddressRange
    parOnpremAddressRange: onpremVnetAddressRange
  }
}

module resolver 'modules/resolver.bicep' = {
  name: 'deploy-resolver-s1'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: vnet.outputs.resolverVnetId
    parInboundSubnetId: vnet.outputs.inboundSubnetId
    parOutboundSubnetId: vnet.outputs.outboundSubnetId
  }
}

module storage 'modules/storage.bicep' = {
  name: 'deploy-storage-s1'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parResolverVnetId: vnet.outputs.resolverVnetId
    parPeSubnetId: vnet.outputs.peSubnetId
  }
}

module modWorkloadVM 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'deploy-vm-workload-s1'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    name: 'vm-workload-${parLocation}'
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
            subnetResourceId: vnet.outputs.workloadSubnetId
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

module onprem 'modules/onprem.bicep' = {
  name: 'deploy-onprem-s1'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parSubnetId: vnet.outputs.onpremSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'deploy-bastion-s1'
  scope: resourceGroup(varResourceGroupName)
  dependsOn: [rg]
  params: {
    parLocation: parLocation
    parVnetId: vnet.outputs.workloadVnetId
  }
}
