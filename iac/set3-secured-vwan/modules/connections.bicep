targetScope = 'resourceGroup'

param parHubId string
param parHubName string
param parConnectivityVnetId string
param parSpokeVnetId string
param parOnpremVnetId string

var varDefaultRouteTableId = '${parHubId}/hubRouteTables/defaultRouteTable'

resource resConnectivityConn 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = {
  name: '${parHubName}/conn-connectivity'
  properties: {
    remoteVirtualNetwork: { id: parConnectivityVnetId }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: { id: varDefaultRouteTableId }
      propagatedRouteTables: {
        ids: [{ id: varDefaultRouteTableId }]
        labels: ['default']
      }
    }
  }
}

resource resSpokeConn 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = {
  name: '${parHubName}/conn-spoke'
  dependsOn: [resConnectivityConn]
  properties: {
    remoteVirtualNetwork: { id: parSpokeVnetId }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: { id: varDefaultRouteTableId }
      propagatedRouteTables: {
        ids: [{ id: varDefaultRouteTableId }]
        labels: ['default']
      }
    }
  }
}

resource resOnpremConn 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-01-01' = {
  name: '${parHubName}/conn-onprem'
  dependsOn: [resSpokeConn]
  properties: {
    remoteVirtualNetwork: { id: parOnpremVnetId }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: { id: varDefaultRouteTableId }
      propagatedRouteTables: {
        ids: [{ id: varDefaultRouteTableId }]
        labels: ['default']
      }
    }
  }
}
