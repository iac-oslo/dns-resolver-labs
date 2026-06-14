# lab-05 - Hub-Spoke: Resolve Private Endpoint from Both Spokes

In this lab you configure both spoke VNets to use the DNS Resolver in the hub. You then verify that spoke VMs can resolve the Storage Account Private Endpoint even though the Private DNS Zone is only linked to the hub VNet.

**Key learning:** You do NOT need to link the Private DNS Zone to each spoke VNet. Because DNS queries from spokes go through the resolver in the hub, Azure DNS resolves zones linked to the hub on their behalf.

```
vm-spoke1 ──DNS query──► Resolver inbound (10.11.0.68, in hub)
                                  │
                         Azure DNS (168.63.129.16, hub context)
                                  │
                    privatelink.blob.core.windows.net
                    (linked to vnet-hub-norwayeast only)
                                  │
                         Private Endpoint IP (10.11.0.x)
```

## Prerequisites

- Lab-04 completed and resources deployed
- Resolver inbound endpoint IP noted (expected: `10.11.0.68`)
- Storage Account FQDN noted

## Task #1 - Configure spoke VNets to use the DNS Resolver

Update DNS server settings on both spoke VNets:

```powershell
# Spoke 1
az network vnet update \
  --name vnet-spoke1-norwayeast \
  --resource-group rg-norwayeast-pdnsr-labs-s2 \
  --dns-servers 10.11.0.68

# Spoke 2
az network vnet update \
  --name vnet-spoke2-norwayeast \
  --resource-group rg-norwayeast-pdnsr-labs-s2 \
  --dns-servers 10.11.0.68
```

!!! info
    The hub VNet does NOT need updating — Azure Bastion and hub workloads use the default Azure DNS. Only the spokes are pointed to the resolver.

Restart both spoke VMs to pick up new DNS settings:

```powershell
az vm restart --name vm-spoke1-norwayeast --resource-group rg-norwayeast-pdnsr-labs-s2
az vm restart --name vm-spoke2-norwayeast --resource-group rg-norwayeast-pdnsr-labs-s2
```

## Task #2 - Verify DNS resolution from spoke1

Connect to `vm-spoke1-norwayeast` via Azure Bastion.

Confirm DNS server in use:

```bash
resolvectl status | grep 'DNS Servers'
```

Expected: `10.11.0.68`

Resolve the Storage Account FQDN:

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected: FQDN resolves to a private IP in `10.11.0.96/28` (subnet-pe in hub):

```
;; ANSWER SECTION:
<storage-account-name>.blob.core.windows.net. 10 IN CNAME <storage>.privatelink.blob.core.windows.net.
<storage-account-name>.privatelink.blob.core.windows.net. 10 IN A 10.11.0.100
```

## Task #3 - Verify DNS resolution from spoke2

Connect to `vm-spoke2-norwayeast` via Azure Bastion and repeat the same test:

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected: same private IP as from spoke1.

!!! success "What you verified"
    Both spoke VMs resolve the private endpoint through the resolver in the hub — without linking the Private DNS Zone to each spoke VNet. The resolver acts as a centralized DNS server for the entire hub-spoke topology.

## Task #4 - Confirm Private DNS Zone is NOT linked to spoke VNets

```powershell
az network private-dns link vnet list \
  --resource-group rg-norwayeast-pdnsr-labs-s2 \
  --zone-name privatelink.blob.core.windows.net \
  --query '[].{name:name, vnet:virtualNetwork.id}' \
  -o table
```

You should see only ONE link — to `vnet-hub-norwayeast`. No links to spoke VNets.

!!! info "Why this works"
    When the DNS Resolver inbound endpoint (in the hub VNet) receives a query and forwards it to Azure DNS (168.63.129.16), Azure DNS uses the **resolver's VNet context** (hub) to look up Private DNS Zones. Since the zone is linked to the hub, Azure DNS can resolve it. The query originates from a spoke VM, but resolution happens in hub context.

You are now ready for [lab-06](../lab-06/index.md).
