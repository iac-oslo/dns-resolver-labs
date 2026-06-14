# lab-04 - Provision Set 2: Hub-Spoke

This lab provisions the infrastructure for labs 05 and 06. It deploys a hub-and-spoke network topology with two spoke VNets, an on-premises simulation VNet, Azure Private DNS Resolver in the hub, a Storage Account with Private Endpoint, and Azure Bastion.

!!! info "Estimated deployment time"
    ~20–25 minutes

!!! tip "Cost"
    Running Set 2 resources for 3 hours costs approximately **$1.92**. Delete the resource group when done with labs 05–06.

!!! tip "Clean up Set 1 first"
    If you still have Set 1 running, delete it to avoid paying for unused resources:
    ```powershell
    az group delete --name rg-norwayeast-pdnsr-labs-s1 --yes --no-wait
    ```

## Task #1 - Deploy lab environment

```powershell
cd dns-resolver-labs/iac/set2-hub-spoke
./deploy.ps1
```

The following resources will be deployed under `rg-norwayeast-pdnsr-labs-s2`:

| Resource | Type |
|----------|------|
| `vnet-hub-norwayeast` | Hub Virtual Network (10.11.0.0/24) |
| `vnet-spoke1-norwayeast` | Spoke1 Virtual Network (10.11.1.0/24) |
| `vnet-spoke2-norwayeast` | Spoke2 Virtual Network (10.11.2.0/24) |
| `vnet-onprem-norwayeast` | On-prem Virtual Network (10.11.3.0/24) |
| `pdnsr-norwayeast` | Private DNS Resolver (in hub) |
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
10.11.0.0/24 (vnet-hub-norwayeast)
├── AzureBastionSubnet   10.11.0.0/26    ← Azure Bastion
├── subnet-inbound       10.11.0.64/28   ← DNS Resolver inbound
├── subnet-outbound      10.11.0.80/28   ← DNS Resolver outbound
├── subnet-pe            10.11.0.96/28   ← Private Endpoint (Storage)
└── subnet-workload      10.11.0.128/26

10.11.1.0/24 (vnet-spoke1-norwayeast, peered to hub)
└── subnet-workload      10.11.1.0/24    ← vm-spoke1-norwayeast

10.11.2.0/24 (vnet-spoke2-norwayeast, peered to hub)
└── subnet-workload      10.11.2.0/24    ← vm-spoke2-norwayeast

10.11.3.0/24 (vnet-onprem-norwayeast, peered to hub)
└── subnet-onprem        10.11.3.0/24    ← vm-onprem-norwayeast
```

### On-prem DNS server

`vm-onprem-norwayeast` is pre-configured with BIND9 serving `onprem.local`:

| Record | IP |
|--------|----|
| `app.onprem.local` | vm-onprem private IP |
| `db.onprem.local` | 10.0.0.10 (synthetic) |

## Task #2 - Verify deployment and note IP addresses

Get the DNS Resolver inbound endpoint IP:

```powershell
az dns-resolver inbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s2 `
  --query '[0].ipConfigurations[0].privateIpAddress' `
  -o tsv
```

Expected: `10.11.0.68` (first available IP in subnet-inbound 10.11.0.64/28)

Get VM private IPs:

```powershell
az vm show -d -g rg-norwayeast-pdnsr-labs-s2 -n vm-spoke1-norwayeast --query privateIps -o tsv
az vm show -d -g rg-norwayeast-pdnsr-labs-s2 -n vm-spoke2-norwayeast --query privateIps -o tsv
az vm show -d -g rg-norwayeast-pdnsr-labs-s2 -n vm-onprem-norwayeast --query privateIps -o tsv
```

| VM | Expected IP |
|----|-------------|
| `vm-spoke1-norwayeast` | 10.11.1.4 |
| `vm-spoke2-norwayeast` | 10.11.2.4 |
| `vm-onprem-norwayeast` | 10.11.3.4 |

Get the Storage Account FQDN:

```powershell
$saName = az storage account list -g rg-norwayeast-pdnsr-labs-s2 --query '[0].name' -o tsv
Write-Host "Storage FQDN: ${saName}.blob.core.windows.net"
```

## Task #3 - Verify Bastion connectivity to spoke VMs

Connect to `vm-spoke1-norwayeast` via Azure Bastion (Bastion is in the hub and can reach all peered VNets):

1. Navigate to `vm-spoke1-norwayeast` in Azure Portal
2. Click **Connect** → **Bastion**
3. Login: `iac-admin` / `fooBar123!`

Verify connectivity:

```bash
ping 10.11.2.4   # vm-spoke2
ping 10.11.3.4   # vm-onprem
```

You are now ready for [lab-05](../lab-05/index.md).
