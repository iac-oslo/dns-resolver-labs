# lab-02 - Single VNet: Resolve Private Endpoint via DNS Resolver

In this lab you configure the workload VM to use the Azure Private DNS Resolver inbound endpoint as its DNS server. You then verify that Private Endpoint DNS resolution works through the resolver.

**Scenario:** A workload VM needs to resolve the private IP of a Storage Account behind a Private Endpoint. Instead of using Azure's default DNS directly, queries flow through the DNS Resolver, which is the single DNS entry point for the VNet.

```
vm-workload ──DNS query──► Resolver inbound (10.10.2.4)
                                    │
                                    ▼
                          Azure DNS (168.63.129.16)
                                    │
                                    ▼
                    privatelink.blob.core.windows.net
                    (linked to vnet-resolver-norwayeast)
                                    │
                                    ▼
                         Private Endpoint IP (10.10.0.x)
```

## Prerequisites

- Lab-01 completed and resources deployed
- Resolver inbound endpoint IP noted (expected: `10.10.2.4`)
- Storage Account FQDN noted (e.g., `sa<unique>.blob.core.windows.net`)

## Task #1 - Verify DNS resolves to a public IP (before state)

Connect to `vm-workload-norwayeast` via Azure Bastion:

1. Navigate to `vm-workload-norwayeast` in Azure Portal
2. Click **Connect** → **Bastion**
3. Login: `iac-admin` / `fooBar123!`

From the VM, resolve the Storage Account FQDN before changing anything:

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected output — the FQDN resolves to a **public IP**:

```
;; ANSWER SECTION:
<storage-account-name>.blob.core.windows.net. 60 IN CNAME <storage-account-name>.privatelink.blob.core.windows.net.
<storage-account-name>.privatelink.blob.core.windows.net. 60 IN CNAME blob.xyz.store.core.windows.net.
blob.xyz.store.core.windows.net. 60 IN A 20.60.x.x
```

The VM currently uses Azure platform DNS (168.63.129.16) directly. Azure DNS evaluates Private DNS Zones in the context of `vnet-workload-norwayeast` — but the Private DNS Zone `privatelink.blob.core.windows.net` is linked to `vnet-resolver-norwayeast`, not the workload VNet. So Azure DNS falls through to public DNS and returns the storage account's public IP.

Disconnect from Bastion. The next task routes DNS through the resolver.

## Task #2 - Configure VNet DNS to use the Resolver inbound endpoint

By default, VMs in a VNet use Azure's platform DNS (168.63.129.16) directly. That works fine for public names, but it bypasses the DNS Resolver entirely — private DNS zone lookups would go straight to Azure DNS without passing through the resolver inbound endpoint. Setting the VNet's DNS server to the resolver inbound IP forces all VM DNS queries through the resolver first, giving the resolver control over how names are resolved (including forwarding on-prem queries in lab-03).

Update `vnet-workload-norwayeast` to use the DNS Resolver inbound endpoint as its DNS server:

```powershell
az network vnet update `
  --name vnet-workload-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --dns-servers 10.10.2.4
```

!!! info
    Replace `10.10.2.4` with the actual inbound endpoint IP if it differs (verify in Task #3 of lab-01).

Verify the DNS setting was applied:

```powershell
az network vnet show `
  --name vnet-workload-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --query 'dhcpOptions.dnsServers' `
  -o tsv
```

## Task #3 - Restart the workload VM to pick up the new DNS settings

VNet DNS settings are delivered to VMs via DHCP. When Azure updates the VNet's DNS server list, running VMs are not notified — they keep using the DNS server from their last DHCP lease until the lease is renewed. A reboot forces the VM to release and re-request its DHCP lease, at which point Azure pushes the updated DNS server address down to the NIC. Without the reboot, `dig` queries from the VM would still go directly to Azure platform DNS (168.63.129.16) and bypass the resolver.

The VM NIC picks up VNet DNS settings on next boot or NIC refresh:

```powershell
az vm restart `
  --name vm-workload-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s1
```

## Task #4 - Resolve the Storage Account Private Endpoint

Connect to `vm-workload-norwayeast` via Azure Bastion:

1. Navigate to `vm-workload-norwayeast` in Azure Portal
2. Click **Connect** → **Bastion**
3. Login: `iac-admin` / `fooBar123!`

Get your Storage Account name first (run from your workstation):

```powershell
az storage account list -g rg-norwayeast-pdnsr-labs-s1 --query '[0].name' -o tsv
```

From the VM, resolve the Storage Account FQDN:

```bash
dig <storage-account-name>.blob.core.windows.net
```

Expected output — the FQDN should now resolve to a **private IP** in the `10.10.0.192/26` range (subnet-pe):

```
;; ANSWER SECTION:
<storage-account-name>.blob.core.windows.net. 10 IN CNAME <storage-account-name>.privatelink.blob.core.windows.net.
<storage-account-name>.privatelink.blob.core.windows.net. 10 IN A 10.10.0.196
```

!!! success "What you verified"
    DNS query from vm-workload → DNS Resolver inbound endpoint (10.10.2.4) → Azure DNS → Private DNS Zone `privatelink.blob.core.windows.net` → Private Endpoint IP.
    
    The VM never queries Azure DNS directly; all queries go through the resolver first.

## Task #5 - Check the DNS server used by the VM

From inside the VM, confirm which DNS server is in use:

```bash
resolvectl status | grep 'DNS Servers'
```

Expected: `10.10.2.4`

## Task #6 - Verify the Private DNS Zone is linked to the VNet

```powershell
az network private-dns link vnet list `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --zone-name privatelink.blob.core.windows.net `
  --query '[].{name:name, vnet:virtualNetwork.id}' `
  -o table
```

You should see a link to `vnet-resolver-norwayeast`.

!!! info "Why link the zone to the resolver VNet?"
    When the DNS Resolver inbound endpoint receives a query for `privatelink.blob.core.windows.net`, it forwards it to Azure DNS (168.63.129.16). Azure DNS resolves Private DNS Zones that are linked to the VNet containing the resolver — which is `vnet-resolver-norwayeast`. This is why the Private DNS Zone must be linked to the **resolver's VNet**, not the workload VNet. Workload VMs reach private DNS records by routing their queries through the resolver.

You are now ready for [lab-03](../lab-03/index.md).
