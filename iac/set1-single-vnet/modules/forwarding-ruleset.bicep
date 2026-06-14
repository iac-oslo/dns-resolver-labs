targetScope = 'resourceGroup'

param parLocation string
param parOutboundEndpointId string
param parVnetId string
param parOnpremDnsServerIP string

module modForwardingRuleset 'br/public:avm/res/network/dns-forwarding-ruleset:0.5.0' = {
  name: 'deploy-pdnsfrs-${parLocation}'
  params: {
    name: 'pdnsfrs-${parLocation}'
    location: parLocation
    dnsForwardingRulesetOutboundEndpointResourceIds: [parOutboundEndpointId]
    forwardingRules: [
      {
        name: 'onprem-local'
        domainName: 'onprem.iac-labs.'
        forwardingRuleState: 'Enabled'
        targetDnsServers: [
          {
            ipAddress: parOnpremDnsServerIP
            port: 53
          }
        ]
      }
    ]
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: parVnetId
      }
    ]
    enableTelemetry: false
  }
}
