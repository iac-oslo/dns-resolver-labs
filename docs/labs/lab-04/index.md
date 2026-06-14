# lab-04 - Provision Set 2: Hub-Spoke with Azure Firewall

This lab provisions the infrastructure for labs 05 and 06. It deploys a hub-spoke network topology with Azure Firewall (Basic SKU) in the hub, configured as a DNS proxy that forwards queries to the Private DNS Resolver. Spoke VMs use the firewall as their DNS server.

!!! info "Estimated deployment time"
    ~25–35 minutes. Azure Firewall Basic takes 12–18 minutes to provision.

!!! warning "Cost"
    Set 2 is the most expensive set. Running for 3 hours costs approximately **$2.94** (12 hours: ~$11.74). Azure Firewall Basic alone costs ~$0.33/hr.

    Delete the resource group promptly when done with labs 05–06.

## Task #1 - Deploy lab environment

```powershell
cd dns-resolver-labs/iac/set2-hub-spoke-azfw
./deploy.ps1
```

The following resources will be deployed under `rg-norwayeast-pdnsr-labs-s3`:

| Resource | Type |
|----------|------|
| `vnet-hub-norwayeast` | Hub Virtual Network (10.12.0.0/23) |
| `vnet-spoke1-norwayeast` | Spoke1 Virtual Network (10.12.2.0/24) |
| `vnet-spoke2-norwayeast` | Spoke2 Virtual Network (10.12.3.0/24) |
| `vnet-onprem-norwayeast` | On-prem Virtual Network (10.12.4.0/24) |
| `pdnsr-norwayeast` | Private DNS Resolver (in hub) |
| `nfp-norwayeast` | Azure Firewall Policy (Basic, DNS Proxy enabled) |
| `naf-norwayeast` | Azure Firewall (Basic) |
| `pip-01-naf-norwayeast` | Public IP for Azure Firewall |
| `vm-spoke1-norwayeast` | Linux VM (B1s, Ubuntu 22.04) |
| `vm-spoke2-norwayeast` | Linux VM (B1s, Ubuntu 22.04) |
| `vm-onprem-norwayeast` | Linux VM (B1s, Ubuntu 22.04) with BIND9 |
| `bastion-norwayeast` | Azure Bastion (Basic, in hub) |
| `pip-bastion-norwayeast` | Public IP for Bastion |
| `sa<unique>` | Storage Account |
| `pe-blob-norwayeast` | Private Endpoint (Blob, in hub) |
| `privatelink.blob.core.windows.net` | Private DNS Zone (linked to hub) |

### Network topology

```
10.12.0.0/23 (vnet-hub-norwayeast)
├── AzureFirewallSubnet           10.12.0.0/26    ← Azure Firewall
├── AzureFirewallManagementSubnet 10.12.0.64/26   ← AzFW Management
├── AzureBastionSubnet            10.12.0.128/26  ← Azure Bastion
├── subnet-inbound                10.12.0.192/28  ← DNS Resolver inbound
├── subnet-outbound               10.12.0.208/28  ← DNS Resolver outbound
└── subnet-pe                     10.12.1.0/27    ← Private Endpoint (Storage)

10.12.2.0/24 (vnet-spoke1-norwayeast, peered to hub)
└── subnet-workload   10.12.2.0/24  ← vm-spoke1-norwayeast

10.12.3.0/24 (vnet-spoke2-norwayeast, peered to hub)
└── subnet-workload   10.12.3.0/24  ← vm-spoke2-norwayeast

10.12.4.0/24 (vnet-onprem-norwayeast, peered to hub)
└── subnet-onprem     10.12.4.0/24  ← vm-onprem-norwayeast
```

### DNS flow with Azure Firewall

```
vm-spoke ──DNS query──► Azure Firewall (DNS Proxy, 10.12.0.4)
                                │
                   Firewall Policy: DNS Proxy → Resolver inbound
                                │
                       Resolver inbound (10.12.0.196)
                                │
                      Azure DNS → Private DNS Zone / Forwarding Ruleset
```

## Task #2 - Verify deployment and note IP addresses

Get the Azure Firewall private IP:

```powershell
az network firewall show `
  --name naf-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query ipConfigurations[0].privateIPAddress `
  -o tsv
```

Expected: `10.12.0.4`

Get the DNS Resolver inbound endpoint IP:

```powershell
az dns-resolver inbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s3 `
  --query '[0].ipConfigurations[0].privateIpAddress' `
  -o tsv
```

Expected: `10.12.0.196`

Confirm the AzFW Firewall Policy is configured with DNS proxy pointing to the resolver:

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
  "servers": ["10.12.0.196"]
}
```

Get VM private IPs:

```powershell
az vm show -d -g rg-norwayeast-pdnsr-labs-s3 -n vm-spoke1-norwayeast --query privateIps -o tsv
az vm show -d -g rg-norwayeast-pdnsr-labs-s3 -n vm-spoke2-norwayeast --query privateIps -o tsv
az vm show -d -g rg-norwayeast-pdnsr-labs-s3 -n vm-onprem-norwayeast --query privateIps -o tsv
```

| VM | Expected IP |
|----|-------------|
| `vm-spoke1-norwayeast` | 10.12.2.4 |
| `vm-spoke2-norwayeast` | 10.12.3.4 |
| `vm-onprem-norwayeast` | 10.12.4.4 |

Get the Storage Account FQDN:

```powershell
$saName = az storage account list -g rg-norwayeast-pdnsr-labs-s3 --query '[0].name' -o tsv
Write-Host "Storage FQDN: ${saName}.blob.core.windows.net"
```

You are now ready for [lab-05](../lab-05/index.md).
