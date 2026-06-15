targetScope = 'resourceGroup'

param parLocation string
param parHubId string
param parHubName string
param parResolverInboundIP string
param parAllCidrs string[]

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

resource resRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-01-01' = {
  name: '${varNfpName}/rcg-set3'
  dependsOn: [modFirewallPolicy]
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'rc-allow-internal'
        priority: 100
        action: { type: 'Allow' }
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            name: 'allow-rfc1918'
            ruleType: 'NetworkRule'
            sourceAddresses: parAllCidrs
            destinationAddresses: parAllCidrs
            ipProtocols: ['Any']
            destinationPorts: ['*']
          }
        ]
      }
      {
        name: 'rc-allow-internet'
        priority: 200
        action: { type: 'Allow' }
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            name: 'allow-http-https'
            ruleType: 'NetworkRule'
            sourceAddresses: parAllCidrs
            destinationAddresses: ['0.0.0.0/0']
            ipProtocols: ['TCP']
            destinationPorts: ['80', '443']
          }
          {
            name: 'allow-ntp-dns'
            ruleType: 'NetworkRule'
            sourceAddresses: parAllCidrs
            destinationAddresses: ['*']
            ipProtocols: ['UDP']
            destinationPorts: ['53', '123']
          }
        ]
      }
    ]
  }
}

resource resFirewall 'Microsoft.Network/azureFirewalls@2024-01-01' = {
  name: varNafName
  location: parLocation
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: 'Basic'
    }
    virtualHub: {
      id: parHubId
    }
    firewallPolicy: {
      id: modFirewallPolicy.outputs.resourceId
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
  }
  dependsOn: [resRuleCollectionGroup]
}

resource resRoutingIntent 'Microsoft.Network/virtualHubs/routingIntent@2024-01-01' = {
  name: '${parHubName}/routing-intent'
  properties: {
    routingPolicies: [
      {
        name: 'PrivateTrafficPolicy'
        destinations: ['PrivateTraffic']
        nextHop: resFirewall.id
      }
      {
        name: 'InternetTrafficPolicy'
        destinations: ['Internet']
        nextHop: resFirewall.id
      }
    ]
  }
}

resource resLaw 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${parLocation}'
  location: parLocation
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource resDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${varNafName}'
  scope: resFirewall
  properties: {
    workspaceId: resLaw.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output azfwPrivateIP string = resFirewall.properties.hubIPAddresses.privateIPAddress
output azfwResourceId string = resFirewall.id
