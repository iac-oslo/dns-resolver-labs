targetScope = 'resourceGroup'

param parLocation string
param parVnetId string
param parInboundSubnetId string
param parOutboundSubnetId string

var varResolverName = 'pdnsr-${parLocation}'

module modResolver 'br/public:avm/res/network/dns-resolver:0.5.0' = {
  name: 'deploy-${varResolverName}'
  params: {
    name: varResolverName
    location: parLocation
    virtualNetworkResourceId: parVnetId
    inboundEndpoints: [
      {
        name: 'inbound-ep'
        subnetResourceId: parInboundSubnetId
      }
    ]
    outboundEndpoints: [
      {
        name: 'outbound-ep'
        subnetResourceId: parOutboundSubnetId
      }
    ]
    enableTelemetry: false
  }
}

var varInboundEndpointId = resourceId('Microsoft.Network/dnsResolvers/inboundEndpoints', varResolverName, 'inbound-ep')
var varOutboundEndpointId = resourceId('Microsoft.Network/dnsResolvers/outboundEndpoints', varResolverName, 'outbound-ep')

output resolverResourceId string = modResolver.outputs.resourceId
output inboundEndpointResourceId string = varInboundEndpointId
output outboundEndpointResourceId string = varOutboundEndpointId
output inboundEndpointIP string = reference(varInboundEndpointId, '2022-07-01').ipConfigurations[0].privateIpAddress
