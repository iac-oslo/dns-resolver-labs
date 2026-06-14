# lab-06 - Hub-Spoke: Resolve On-Prem DNS from Spokes

In this lab you create a DNS Forwarding Ruleset (IaC task) and link it to both spoke VNets. Spoke VMs then resolve `onprem.local` records through the DNS Resolver, which forwards the queries to the on-prem BIND9 server.

**Scenario:** Workloads in hub-spoke spokes need to resolve internal DNS records from the on-premises network. The forwarding ruleset in the resolver handles the routing.

```
vm-spoke1 ──dig app.onprem.local──► Resolver inbound (10.11.0.68)
                                             │
                          Forwarding Ruleset: onprem.local → vm-onprem IP
                                             │
                              Resolver outbound endpoint
                                             │
                              vm-onprem-norwayeast BIND9 (10.11.3.4)
                                             │
                                    app.onprem.local resolved
```

## Prerequisites

- Lab-05 completed
- Spoke VNet DNS already set to `10.11.0.68`
- On-prem VM IP noted (expected: `10.11.3.4`)
- Outbound endpoint resource ID:

```powershell
az dns-resolver outbound-endpoint list \
  --dns-resolver-name pdnsr-norwayeast \
  --resource-group rg-norwayeast-pdnsr-labs-s2 \
  --query '[0].id' -o tsv
```

## Task #1 - Write the DNS Forwarding Ruleset Bicep module

Create `iac/set2-hub-spoke/modules/forwarding-ruleset.bicep`:

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
  --resource-group rg-norwayeast-pdnsr-labs-s2 `
  --query '[0].id' -o tsv

$spoke1VnetId = az network vnet show `
  --name vnet-spoke1-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s2 `
  --query id -o tsv

$spoke2VnetId = az network vnet show `
  --name vnet-spoke2-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s2 `
  --query id -o tsv

$onpremIP = az vm show -d `
  --name vm-onprem-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s2 `
  --query privateIps -o tsv
```

Deploy:

```powershell
cd dns-resolver-labs/iac/set2-hub-spoke

az deployment group create `
  --resource-group rg-norwayeast-pdnsr-labs-s2 `
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
app.onprem.local.   300   IN   A   10.11.3.4
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

Repeat from `vm-spoke2-norwayeast` — should return the same results.

!!! success "What you verified"
    Both spoke VMs can resolve on-premises DNS records through a single DNS Resolver. The forwarding ruleset is linked to both spoke VNets. The on-prem BIND9 server answers queries forwarded through the resolver's outbound endpoint.

## Task #4 - Verify Storage Account PE resolution still works

Forwarding rules only apply to `onprem.local.` — everything else still resolves normally:

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected: private IP in the PE subnet.

!!! tip "Clean up Set 2 resources"
    Before proceeding to lab-07, you can optionally delete Set 2 resources:
    ```powershell
    az group delete --name rg-norwayeast-pdnsr-labs-s2 --yes --no-wait
    ```
