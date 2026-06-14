# lab-05 - Hub-Spoke + Azure Firewall: Resolve Private Endpoint via DNS Proxy

In this lab you configure spoke VMs to use the Azure Firewall as their DNS server. The firewall's DNS proxy forwards queries to the Private DNS Resolver, which resolves Private Endpoint records through the Private DNS Zone.

**Scenario:** In a hub-spoke topology secured by Azure Firewall, DNS queries from spokes pass through the firewall before reaching the resolver. This allows centralized DNS logging and control.

```
vm-spoke ──DNS query──► Azure Firewall DNS Proxy (10.12.0.4)
                                │
                   Firewall Policy DNS servers: [10.12.0.196]
                                │
                       Resolver inbound (10.12.0.196)
                                │
                     Azure DNS (168.63.129.16, hub context)
                                │
                 privatelink.blob.core.windows.net (linked to hub)
                                │
                       Private Endpoint IP (10.12.1.x)
```

## Prerequisites

- Lab-07 completed and resources deployed
- Azure Firewall private IP: `10.12.0.4`
- Resolver inbound endpoint IP: `10.12.0.196`
- Storage Account FQDN noted

## Task #1 - Configure spoke VNets to use Azure Firewall as DNS server

Point both spoke VNets to the Azure Firewall private IP (not the resolver directly):

```powershell
# Spoke 1
az network vnet update `
  --name vnet-spoke1-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --dns-servers 10.12.0.4

# Spoke 2
az network vnet update `
  --name vnet-spoke2-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --dns-servers 10.12.0.4
```

Restart spoke VMs to pick up the new DNS settings:

```powershell
az vm restart --name vm-spoke1-norwayeast --resource-group rg-norwayeast-pdnsr-labs-s3
az vm restart --name vm-spoke2-norwayeast --resource-group rg-norwayeast-pdnsr-labs-s3
```

## Task #2 - Verify DNS server on spoke VMs

Connect to `vm-spoke1-norwayeast` via Azure Bastion.

Check the DNS server:

```bash
resolvectl status | grep 'DNS Servers'
```

Expected: `10.12.0.4` (Azure Firewall IP)

## Task #3 - Resolve the Storage Account Private Endpoint

From `vm-spoke1-norwayeast`:

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected: resolves to a private IP in `10.12.1.0/27` (subnet-pe):

```
;; ANSWER SECTION:
<storage-account-name>.blob.core.windows.net. 10 IN CNAME <storage>.privatelink.blob.core.windows.net.
<storage-account-name>.privatelink.blob.core.windows.net. 10 IN A 10.12.1.4
```

Repeat from `vm-spoke2-norwayeast` — same result expected.

!!! success "What you verified"
    DNS resolution path: spoke VM → AzFW DNS Proxy (10.12.0.4) → DNS Resolver inbound (10.12.0.196) → Azure DNS → Private DNS Zone → PE private IP.
    
    Azure Firewall acts as the DNS entry point for all spoke traffic. The resolver handles the actual DNS resolution.

## Task #4 - Inspect Azure Firewall DNS proxy settings

Confirm the policy DNS proxy is enabled and points to the resolver:

```powershell
az network firewall policy show `
  --name nfp-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query 'dnsSettings' `
  -o json
```

## Task #5 - Compare with direct resolver access

For comparison, temporarily point one spoke to the resolver directly (bypassing AzFW):

```powershell
az network vnet update `
  --name vnet-spoke1-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --dns-servers 10.12.0.196
```

Restart `vm-spoke1-norwayeast` and re-test — resolution should still work. Then restore:

```powershell
az network vnet update `
  --name vnet-spoke1-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --dns-servers 10.12.0.4
```

!!! info "Why route through Azure Firewall?"
    When DNS proxy is enabled on Azure Firewall, all DNS queries from spoke VMs are visible in the firewall logs. This provides a single point of DNS observability and allows DNS-based FQDN filtering in network rules. Bypassing the firewall (pointing spokes directly to the resolver) would lose this visibility.

You are now ready for [lab-06](../lab-06/index.md).
