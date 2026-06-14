# lab-03 - Single VNet: Resolve On-Prem DNS via Forwarding Ruleset

In this lab you create a DNS Forwarding Ruleset using Bicep (IaC task). The ruleset tells the DNS Resolver to forward queries for `onprem.local` to the on-prem DNS server (BIND9 running on `vm-onprem-norwayeast`).

**Scenario:** A workload VM needs to resolve internal hostnames from an on-premises DNS zone (`onprem.local`). The DNS Resolver outbound endpoint forwards matching queries to the on-prem DNS server.

```
vm-workload ──dig app.onprem.local──► Resolver inbound (10.10.0.4)
                                               │
                              Forwarding Ruleset: onprem.local → vm-onprem IP
                                               │
                                               ▼
                               Resolver outbound endpoint
                                               │
                                               ▼
                              vm-onprem-norwayeast BIND9 (port 53)
                                               │
                                               ▼
                                      app.onprem.local = vm-onprem IP
```

## Prerequisites

- Lab-02 completed
- VNet DNS server already set to `10.10.0.4` (DNS Resolver inbound)
- On-prem VM IP noted (expected: `10.10.1.4`)
- Outbound endpoint resource ID noted:

```powershell
az dns-resolver outbound-endpoint list \
  --dns-resolver-name pdnsr-norwayeast \
  --resource-group rg-norwayeast-pdnsr-labs-s1 \
  --query '[0].id' \
  -o tsv
```

## Task #1 - Write the DNS Forwarding Ruleset Bicep module

Create a new file `iac/set1-single-vnet/modules/forwarding-ruleset.bicep`:

```bicep
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
        virtualNetworkResourceId: parVnetId
      }
    ]
    enableTelemetry: false
  }
}
```

## Task #2 - Deploy the Forwarding Ruleset

Get the required values:

```powershell
$outboundEpId = az dns-resolver outbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --query '[0].id' -o tsv

$vnetId = az network vnet show `
  --name vnet-single-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --query id -o tsv

$onpremIP = az vm show -d `
  --name vm-onprem-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --query privateIps -o tsv
```

Deploy the ruleset:

```powershell
cd dns-resolver-labs/iac/set1-single-vnet

az deployment group create `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --template-file modules/forwarding-ruleset.bicep `
  --parameters `
    parLocation=norwayeast `
    parOutboundEndpointId=$outboundEpId `
    parVnetId=$vnetId `
    parOnpremDnsServerIP=$onpremIP
```

## Task #3 - Verify the forwarding ruleset was created

```powershell
az dns-resolver forwarding-ruleset list \
  --resource-group rg-norwayeast-pdnsr-labs-s1 \
  --query '[].{name:name, state:provisioningState}' \
  -o table
```

## Task #4 - Resolve on-prem DNS records

Connect to `vm-workload-norwayeast` via Azure Bastion.

Resolve the `app.onprem.local` record — registered in BIND9 with the on-prem VM's IP:

```bash
dig app.onprem.local
```

Expected output:

```
;; ANSWER SECTION:
app.onprem.local.   300   IN   A   10.10.1.4
```

Resolve the synthetic `db.onprem.local` record:

```bash
dig db.onprem.local
```

Expected output:

```
;; ANSWER SECTION:
db.onprem.local.   300   IN   A   10.0.0.10
```

!!! success "What you verified"
    Queries for `onprem.local` domain are forwarded by the DNS Resolver outbound endpoint to the on-prem BIND9 server. The on-prem server responds with the correct records. The workload VM never needed direct network access to a DNS server in a different zone — the resolver handles the forwarding.

## Task #5 - Verify that Private Endpoint resolution still works

DNS forwarding rules only apply to matching domains. Azure DNS still handles everything else:

```bash
dig <storage-account-name>.blob.core.windows.net
```

This should still resolve to the Private Endpoint IP — the forwarding ruleset only intercepts `onprem.local.` queries.

!!! tip "Clean up Set 1 resources"
    Before proceeding to lab-04, you can optionally delete Set 1 resources to save cost:
    ```powershell
    az group delete --name rg-norwayeast-pdnsr-labs-s1 --yes --no-wait
    ```
