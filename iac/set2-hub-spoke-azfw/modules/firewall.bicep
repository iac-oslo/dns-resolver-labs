targetScope = 'resourceGroup'

param parLocation string
param parHubVnetId string
param parResolverInboundIP string
param parSpokeCidrs string[]

var varNafName = 'naf-${parLocation}'
var varNfpName = 'nfp-${parLocation}'

module modFirewallPolicy 'br/public:avm/res/network/firewall-policy:0.3.1' = {
  name: 'deploy-${varNfpName}'
  params: {
    name: varNfpName
    location: parLocation
    tier: 'Basic'
    threatIntelMode: 'Off'
    enableProxy: true
    servers: [parResolverInboundIP]
    enableTelemetry: false
  }
}

resource resSpokePolicyRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-01-01' = {
  name: '${varNfpName}/rcg-spoke-to-spoke'
  dependsOn: [modFirewallPolicy]
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'rc-allow-spoke-to-spoke'
        priority: 100
        action: { type: 'Allow' }
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            name: 'allow-spoke-to-spoke'
            ruleType: 'NetworkRule'
            sourceAddresses: parSpokeCidrs
            destinationAddresses: parSpokeCidrs
            ipProtocols: ['Any']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
}

module modAzureFirewall 'br/public:avm/res/network/azure-firewall:0.8.0' = {
  name: 'deploy-${varNafName}'
  params: {
    name: varNafName
    location: parLocation
    azureSkuTier: 'Basic'
    virtualNetworkResourceId: parHubVnetId
    firewallPolicyId: modFirewallPolicy.outputs.resourceId
    publicIPAddressObject: {
      name: 'pip-01-${varNafName}'
      publicIPAllocationMethod: 'Static'
      skuName: 'Standard'
      skuTier: 'Regional'
    }
    enableTelemetry: false
  }
}

output firewallPrivateIP string = modAzureFirewall.outputs.privateIp
output firewallResourceId string = modAzureFirewall.outputs.resourceId
