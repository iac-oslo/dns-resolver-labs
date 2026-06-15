# lab-09 - Secured VWAN + Azure Firewall: Resolve Private Endpoint via DNS Proxy

In this lab you verify that spoke VMs resolve Private Endpoint FQDNs through the Azure Firewall DNS proxy and the Private DNS Resolver. Unlike Set 2, the DNS server is pre-configured on the spoke VNet at deploy time — no manual VNet update is needed.

**Scenario:** In a Secured VWAN topology, all traffic (including DNS) from spoke VMs routes through the Azure Firewall. The firewall's DNS proxy forwards queries to the Private DNS Resolver, which resolves Private Endpoint records through the Private DNS Zone.

```
vm-spoke ──DNS query──► Azure Firewall DNS Proxy (hub IP)
                                │
                   Firewall Policy DNS servers: [10.13.2.132]
                                │
                       Resolver inbound (10.13.2.132)
                                │
                     Azure DNS (168.63.129.16, connectivity VNet context)
                                │
                 privatelink.blob.core.windows.net (linked to connectivity VNet)
                                │
                       Private Endpoint IP (10.13.2.x)
```

## Prerequisites

- Lab-08 completed and all resources deployed
- AzFW hub private IP noted (from `$azfwIP` in lab-08)
- Resolver inbound endpoint IP: `10.13.2.132`
- Storage Account FQDN noted

## Task #1 - Verify DNS server pre-configuration on spoke VNet

In Secured VWAN, the AzFW hub IP is known at deploy time (from Bicep outputs), so the spoke VNet is configured with the correct DNS server automatically. Verify it is set:

```powershell
az network vnet show `
  --name vnet-spoke-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query 'dhcpOptions.dnsServers' `
  -o tsv
```

Expected: the AzFW hub private IP (within `10.13.0.0/23`).

!!! info "Why is this different from Set 2?"
    In Set 2 (hub-spoke), the AzFW private IP is always `10.12.0.4` (first IP in `AzureFirewallSubnet`). In Secured VWAN, the firewall IP is assigned dynamically from the hub address space — it can only be determined after the firewall is provisioned. The Bicep orchestration in Set 3 deploys the firewall first, then passes its IP to the spoke module, so the DNS server is set correctly in a single deployment.

## Task #2 - Verify DNS server on spoke VM

Connect to `vm-spoke-norwayeast` via Azure Bastion (`bastion-norwayeast` in `vnet-connectivity-norwayeast`).

Check the DNS server in use:

```bash
resolvectl status | grep 'DNS Servers'
```

Expected: AzFW hub private IP (within `10.13.0.0/23`).

## Task #3 - Resolve the Storage Account Private Endpoint

From `vm-spoke-norwayeast`:

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected: resolves to a private IP in `10.13.2.192/27` (subnet-pe):

```
;; ANSWER SECTION:
<storage-account-name>.blob.core.windows.net. 10 IN CNAME <storage>.privatelink.blob.core.windows.net.
<storage-account-name>.privatelink.blob.core.windows.net. 10 IN A 10.13.2.196
```

!!! success "What you verified"
    DNS resolution path: spoke VM → AzFW DNS Proxy (hub IP) → DNS Resolver inbound (10.13.2.132) → Azure DNS → Private DNS Zone → PE private IP.

    The Private DNS Zone is linked to the connectivity VNet (which hosts the resolver's inbound endpoint), so Azure DNS resolves it correctly regardless of which VNet the query originated from.

## Task #4 - Inspect Azure Firewall DNS proxy logs in Log Analytics

Set 3 ships with a Log Analytics Workspace and firewall diagnostic settings pre-configured. Query DNS proxy logs:

```powershell
az monitor log-analytics query `
  --workspace law-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --analytics-query "AZFWDnsQuery | where TimeGenerated > ago(10m) | project TimeGenerated, QueryName, ResponseCode, SourceIp | limit 20" `
  -o table
```

!!! info "Resource Specific tables"
    Logs are stored in resource-specific tables (`AZFWDnsQuery`, `AZFWNetworkRule`, `AZFWApplicationRule`) rather than the generic `AzureDiagnostics` table. This provides better query performance and schema clarity.

## Task #5 - Verify Routing Intent is filtering traffic

Confirm internet access works through the firewall (AzFW network rule allows TCP 80/443):

```bash
curl -I https://azure.microsoft.com
```

Expected: HTTP 200 response (traffic transits AzFW via Routing Intent).

Check that apt-get update works (validates outbound internet path through AzFW):

```bash
sudo apt-get update
```

Expected: package lists update successfully.

Query AzFW network rule logs to confirm traffic is flowing through the firewall:

```powershell
az monitor log-analytics query `
  --workspace law-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --analytics-query "AZFWNetworkRule | where TimeGenerated > ago(10m) | project TimeGenerated, SourceIp, DestinationIp, DestinationPort, Action | limit 20" `
  -o table
```

You are now ready for [lab-10](../lab-10/index.md).
