# lab-09 - Hub-Spoke + Azure Firewall: Resolve On-Prem DNS via DNS Proxy

In this lab you create a DNS Forwarding Ruleset (IaC task) so that `onprem.local` queries from spoke VMs flow through the Azure Firewall DNS proxy, through the DNS Resolver outbound endpoint, and reach the on-prem BIND9 server.

**Full resolution chain:**

```
vm-spoke ──dig app.onprem.local──► AzFW DNS Proxy (10.12.0.4)
                                           │
                          Firewall policy DNS server: [10.12.0.196]
                                           │
                               Resolver inbound (10.12.0.196)
                                           │
                    Forwarding Ruleset: onprem.local → vm-onprem IP
                                           │
                         Resolver outbound endpoint (10.12.0.208/28)
                                           │
                         vm-onprem BIND9 (10.12.4.4, port 53)
                                           │
                              app.onprem.local = 10.12.4.4
```

## Prerequisites

- Lab-08 completed
- Spoke VNets DNS set to Azure Firewall IP (`10.12.0.4`)
- On-prem VM IP noted (expected: `10.12.4.4`)
- Outbound endpoint resource ID:

```powershell
az dns-resolver outbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query '[0].id' -o tsv
```

## Task #1 - Write the DNS Forwarding Ruleset Bicep module

Create `iac/set3-hub-spoke-azfw/modules/forwarding-ruleset.bicep`:

```bicep
targetScope = 'resourceGroup'

param parLocation string
param parOutboundEndpointId string
param parSpoke1VnetId string
param parSpoke2VnetId string
param parOnpremDnsServerIP string

module modForwardingRuleset 'br/public:avm/res/network/dns-forwarding-ruleset:0.5.0' = {
  name: 'deploy-pdnsfrs-${parLocation}'
  params: {
    name: 'pdnsfrs-${parLocation}'
    location: parLocation
    dnsResolverOutboundEndpointResourceIds: [parOutboundEndpointId]
    forwardingRules: [
      {
        name: 'onprem-local'
        domainName: 'onprem.local.'
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
        virtualNetworkResourceId: parSpoke1VnetId
      }
      {
        virtualNetworkResourceId: parSpoke2VnetId
      }
    ]
    enableTelemetry: false
  }
}
```

## Task #2 - Deploy the Forwarding Ruleset

Get required values:

```powershell
$outboundEpId = az dns-resolver outbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query '[0].id' -o tsv

$spoke1VnetId = az network vnet show `
  --name vnet-spoke1-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query id -o tsv

$spoke2VnetId = az network vnet show `
  --name vnet-spoke2-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query id -o tsv

$onpremIP = az vm show -d `
  --name vm-onprem-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query privateIps -o tsv
```

Deploy:

```powershell
cd dns-resolver-labs/iac/set3-hub-spoke-azfw

az deployment group create `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --template-file modules/forwarding-ruleset.bicep `
  --parameters `
    parLocation=norwayeast `
    parOutboundEndpointId=$outboundEpId `
    parSpoke1VnetId=$spoke1VnetId `
    parSpoke2VnetId=$spoke2VnetId `
    parOnpremDnsServerIP=$onpremIP
```

## Task #3 - Verify on-prem DNS resolution from spoke VMs

Connect to `vm-spoke1-norwayeast` via Azure Bastion.

Resolve `app.onprem.local`:

```bash
dig app.onprem.local
```

Expected:

```
;; ANSWER SECTION:
app.onprem.local.   300   IN   A   10.12.4.4
```

Resolve `db.onprem.local`:

```bash
dig db.onprem.local
```

Expected:

```
;; ANSWER SECTION:
db.onprem.local.   300   IN   A   10.0.0.10
```

Repeat from `vm-spoke2-norwayeast` — same results expected.

!!! success "What you verified"
    The complete DNS resolution chain with Azure Firewall as DNS proxy:
    1. Spoke VM sends DNS query to Azure Firewall (10.12.0.4)
    2. Firewall DNS proxy forwards to DNS Resolver inbound (10.12.0.196)
    3. Resolver matches the `onprem.local.` forwarding rule
    4. Resolver outbound endpoint sends query to on-prem BIND9 (10.12.4.4)
    5. BIND9 returns the record
    6. Answer flows back through resolver → firewall → VM

## Task #4 - Verify Private Endpoint resolution still works

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected: private IP in subnet-pe. Both PE resolution and on-prem DNS forwarding work simultaneously.

You are now ready for [lab-10](../lab-10/index.md).
