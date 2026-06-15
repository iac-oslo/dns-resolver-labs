# lab-10 - Secured VWAN + Azure Firewall: Resolve On-Prem DNS via DNS Proxy

In this lab you create a DNS Forwarding Ruleset so that `onprem.iac-labs` queries from the spoke VM flow through the Azure Firewall DNS proxy, through the DNS Resolver outbound endpoint, and reach the on-prem BIND9 server.

**Full resolution chain:**

```
vm-spoke ──dig app.onprem.iac-labs──► AzFW DNS Proxy (hub IP)
                                           │
                          Firewall policy DNS server: [10.13.2.132]
                                           │
                               Resolver inbound (10.13.2.132)
                                           │
                    Forwarding Ruleset: onprem.iac-labs → vm-onprem IP
                                           │
                         Resolver outbound endpoint (10.13.2.144/28)
                                           │
                         vm-onprem BIND9 (10.13.5.4, port 53)
                                           │
                              app.onprem.iac-labs = 10.13.5.4
```

## Prerequisites

- Lab-09 completed
- On-prem VM IP: `10.13.5.4`
- Outbound endpoint resource ID:

```powershell
$outboundEpId = az dns-resolver outbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query '[0].id' -o tsv
```

## Task #1 - Write the DNS Forwarding Ruleset Bicep module

Create `iac/set3-secured-vwan/modules/forwarding-ruleset.bicep`:

```bicep
targetScope = 'resourceGroup'

param parLocation string
param parOutboundEndpointId string
param parConnectivityVnetId string
param parSpokeVnetId string
param parOnpremDnsServerIP string

module modForwardingRuleset 'br/public:avm/res/network/dns-forwarding-ruleset:0.5.0' = {
  name: 'deploy-pdnsfrs-${parLocation}'
  params: {
    name: 'pdnsfrs-${parLocation}'
    location: parLocation
    dnsForwardingRulesetOutboundEndpointResourceIds: [parOutboundEndpointId]
    forwardingRules: [
      {
        name: 'onprem-iac-labs'
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
        virtualNetworkResourceId: parConnectivityVnetId
      }
      {
        virtualNetworkResourceId: parSpokeVnetId
      }
    ]
    enableTelemetry: false
  }
}
```

!!! info "Why link to the connectivity VNet?"
    In VWAN topology, DNS queries from spoke VMs arrive at the resolver's inbound endpoint (in the connectivity VNet) after transiting the AzFW proxy. From the resolver's perspective, the effective VNet context is the connectivity VNet. Linking the forwarding ruleset to the connectivity VNet ensures the forwarding rules are evaluated for these queries. The spoke VNet link provides a direct path if VMs ever query the resolver's inbound endpoint without going through the firewall.

## Task #2 - Deploy the Forwarding Ruleset

Get required values:

```powershell
$outboundEpId = az dns-resolver outbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query '[0].id' -o tsv

$connectivityVnetId = az network vnet show `
  --name vnet-connectivity-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query id -o tsv

$spokeVnetId = az network vnet show `
  --name vnet-spoke-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query id -o tsv

$onpremIP = az vm show -d `
  --name vm-onprem-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query privateIps -o tsv
```

Deploy:

```powershell
cd dns-resolver-labs/iac/set3-secured-vwan

az deployment group create `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --template-file modules/forwarding-ruleset.bicep `
  --parameters `
    parLocation=norwayeast `
    parOutboundEndpointId=$outboundEpId `
    parConnectivityVnetId=$connectivityVnetId `
    parSpokeVnetId=$spokeVnetId `
    parOnpremDnsServerIP=$onpremIP
```

## Task #3 - Verify on-prem DNS resolution from spoke VM

Connect to `vm-spoke-norwayeast` via Azure Bastion.

Resolve `app.onprem.iac-labs`:

```bash
dig app.onprem.iac-labs
```

Expected:

```
;; ANSWER SECTION:
app.onprem.iac-labs.   300   IN   A   10.13.5.4
```

Resolve `db.onprem.iac-labs`:

```bash
dig db.onprem.iac-labs
```

Expected:

```
;; ANSWER SECTION:
db.onprem.iac-labs.   300   IN   A   10.0.0.10
```

!!! success "What you verified"
    The complete DNS resolution chain with Azure Firewall in Secured VWAN:

    1. Spoke VM sends DNS query to Azure Firewall (hub IP, via Routing Intent)
    2. Firewall DNS proxy forwards to DNS Resolver inbound (10.13.2.132)
    3. Resolver matches the `onprem.iac-labs.` forwarding rule
    4. Resolver outbound endpoint sends query to on-prem BIND9 (10.13.5.4)
    5. BIND9 returns the record
    6. Answer flows back through resolver → firewall → VM

## Task #4 - Verify Private Endpoint resolution still works

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected: private IP in `10.13.2.192/27`. Both PE resolution and on-prem DNS forwarding work simultaneously.

## Task #5 - Inspect forwarding activity in Log Analytics

Query DNS proxy logs to see forwarded queries:

```powershell
az monitor log-analytics query `
  --workspace law-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --analytics-query "AZFWDnsQuery | where TimeGenerated > ago(10m) | where QueryName contains 'onprem.iac-labs' | project TimeGenerated, QueryName, ResponseCode, SourceIp" `
  -o table
```

You are now ready for [lab-07](../lab-07/index.md) to clean up all resources.
