targetScope = 'resourceGroup'

param parLocation string
param parHubVnetId string
param parResolverInboundIP string

var varNafName = 'naf-${parLocation}'

module modFirewallPolicy 'br/public:avm/res/network/firewall-policy:0.3.1' = {
  name: 'deploy-nfp-${parLocation}'
  params: {
    name: 'nfp-${parLocation}'
    location: parLocation
    tier: 'Basic'
    threatIntelMode: 'Off'
    enableProxy: true
    servers: [parResolverInboundIP]
    enableTelemetry: false
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
