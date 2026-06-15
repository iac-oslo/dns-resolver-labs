# lab-08 - Provision Set 3: Secured VWAN with Azure Firewall

This lab provisions the infrastructure for labs 09 and 10. It deploys a Secured Virtual WAN topology with Azure Firewall (Basic SKU) as a Secured Hub, configured as a DNS proxy that forwards queries to the Private DNS Resolver in the connectivity VNet. Routing Intent routes both internet and private traffic through the firewall.

!!! info "Estimated deployment time"
    ~35–50 minutes. VWAN hub provisioning takes 10–15 minutes, Azure Firewall in Secured Hub takes an additional 15–20 minutes.

!!! warning "Cost"
    Set 3 costs approximately **$2.45 for 3 hours** (~$9.80 for 12 hours). Azure Firewall and Bastion are the main cost drivers. Delete the resource group promptly when done with labs 09–10.

## Task #1 - Deploy lab environment

```powershell
cd dns-resolver-labs/iac/set3-secured-vwan
./deploy.ps1
```

The following resources will be deployed under `rg-norwayeast-pdnsr-labs-s3`:

| Resource | Type |
|----------|------|
| `vwan-norwayeast` | Virtual WAN (Standard) |
| `vhub-norwayeast` | Virtual Hub (10.13.0.0/23) |
| `nfp-norwayeast` | Azure Firewall Policy (Basic, DNS Proxy enabled) |
| `naf-norwayeast` | Azure Firewall (Basic, Secured Hub) |
| `vnet-connectivity-norwayeast` | Connectivity Virtual Network (10.13.2.0/23) |
| `vnet-spoke-norwayeast` | Spoke Virtual Network (10.13.4.0/24) |
| `vnet-onprem-norwayeast` | On-prem Virtual Network (10.13.5.0/24) |
| `pdnsr-norwayeast` | Private DNS Resolver (in connectivity VNet) |
| `vm-spoke-norwayeast` | Linux VM (B1s, Ubuntu 22.04) |
| `vm-onprem-norwayeast` | Linux VM (B1s, Ubuntu 22.04) with BIND9 |
| `bastion-norwayeast` | Azure Bastion (Basic, in connectivity VNet) |
| `pip-bastion-norwayeast` | Public IP for Bastion |
| `law-norwayeast` | Log Analytics Workspace |
| `sa<unique>` | Storage Account |
| `pe-blob-norwayeast` | Private Endpoint (Blob, in connectivity VNet) |
| `privatelink.blob.core.windows.net` | Private DNS Zone (linked to connectivity VNet) |

### Network topology

```
Virtual WAN (Standard)
└── vhub-norwayeast (10.13.0.0/23)
    ├── naf-norwayeast — Azure Firewall Basic (Secured Hub)
    │   └── Routing Intent: Internet + Private → AzFW
    ├── conn-connectivity → vnet-connectivity-norwayeast
    ├── conn-spoke       → vnet-spoke-norwayeast
    └── conn-onprem      → vnet-onprem-norwayeast

10.13.2.0/23 (vnet-connectivity-norwayeast)
├── AzureBastionSubnet  10.13.2.0/26    ← Azure Bastion
├── subnet-inbound      10.13.2.128/28  ← DNS Resolver inbound endpoint
├── subnet-outbound     10.13.2.144/28  ← DNS Resolver outbound endpoint
└── subnet-pe           10.13.2.192/27  ← Private Endpoint (Storage)

10.13.4.0/24 (vnet-spoke-norwayeast)
└── subnet-workload     10.13.4.0/24    ← vm-spoke-norwayeast

10.13.5.0/24 (vnet-onprem-norwayeast)
└── subnet-onprem       10.13.5.0/24    ← vm-onprem-norwayeast
```

### DNS flow with Azure Firewall in VWAN

```
vm-spoke ──DNS query──► Azure Firewall DNS Proxy (hub IP)
                                │
                   Firewall Policy: DNS Proxy → Resolver inbound
                                │
                       Resolver inbound (10.13.2.132)
                                │
                      Azure DNS → Private DNS Zone / Forwarding Ruleset
```

!!! info "Key differences from Set 2 (Hub-Spoke)"
    - No hub VNet or VNet peering — VWAN hub manages all connectivity
    - No route tables on spoke subnets — Routing Intent replaces manual UDRs
    - Spoke VNet DNS is pre-configured to AzFW IP at deploy time (since the IP is known from Bicep outputs)
    - Azure Firewall runs as a Secured Hub resource, not in `AzureFirewallSubnet`
    - All traffic (internet and private) is routed through the firewall by Routing Intent

## Task #2 - Verify deployment and note IP addresses

Get the Azure Firewall private IP (assigned from hub address space):

```powershell
$azfwIP = az network firewall show `
  --name naf-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query 'hubIPAddresses.privateIPAddress' `
  -o tsv
Write-Host "AzFW private IP: $azfwIP"
```

The IP is within `10.13.0.0/23` (hub address space).

Get the DNS Resolver inbound endpoint IP:

```powershell
az dns-resolver inbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query '[0].ipConfigurations[0].privateIpAddress' `
  -o tsv
```

Expected: `10.13.2.132`

Confirm the Firewall Policy is configured with DNS proxy pointing to the resolver:

```powershell
az network firewall policy show `
  --name nfp-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query 'dnsSettings' `
  -o json
```

Expected:

```json
{
  "enableProxy": true,
  "servers": ["10.13.2.132"]
}
```

Verify Routing Intent is applied to the hub:

```powershell
az network vhub routing-intent show `
  --name routing-intent `
  --vhub-name vhub-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query 'routingPolicies[].{name:name, destinations:destinations}' `
  -o table
```

Expected:

```
Name                   Destinations
---------------------  --------------------------------
PrivateTrafficPolicy   ['PrivateTraffic']
InternetTrafficPolicy  ['Internet']
```

Confirm spoke VNet has AzFW as DNS server (pre-configured at deploy time):

```powershell
az network vnet show `
  --name vnet-spoke-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query 'dhcpOptions.dnsServers' `
  -o tsv
```

Expected: the AzFW hub private IP.

Get VM private IPs:

```powershell
az vm show -d -g rg-norwayeast-pdnsr-labs-s3 -n vm-spoke-norwayeast --query privateIps -o tsv
az vm show -d -g rg-norwayeast-pdnsr-labs-s3 -n vm-onprem-norwayeast --query privateIps -o tsv
```

| VM | Expected IP |
|----|-------------|
| `vm-spoke-norwayeast` | 10.13.4.4 |
| `vm-onprem-norwayeast` | 10.13.5.4 |

Get the Storage Account FQDN:

```powershell
$saName = az storage account list -g rg-norwayeast-pdnsr-labs-s3 --query '[0].name' -o tsv
Write-Host "Storage FQDN: ${saName}.blob.core.windows.net"
```

You are now ready for [lab-09](../lab-09/index.md).
