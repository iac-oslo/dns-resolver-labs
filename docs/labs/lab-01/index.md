# lab-01 - Provision Set 1: Single VNet

This lab provisions the infrastructure for labs 02 and 03. It deploys a single VNet with Azure Private DNS Resolver, a workload VM, an on-premises simulation VM with BIND9, a Storage Account with a Private Endpoint, and Azure Bastion for connectivity.

!!! info "Estimated deployment time"
    ~8–10 minutes

!!! tip "Cost"
    Running Set 1 resources for 3 hours costs approximately **$1.88**. The most expensive resource is the DNS Resolver (~$0.40/hr for both endpoints). Delete the resource group when done with labs 02–03 to avoid unnecessary charges.

## Task #1 - Register resource providers

```powershell
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Resources
```

Install required az CLI extensions:

```powershell
az extension add -n bastion
az extension add -n dns-resolver
```

## Task #2 - Deploy lab environment

Clone the repository and deploy Set 1:

```powershell
git clone https://github.com/iac-oslo/dns-resolver-labs.git
cd dns-resolver-labs/iac/set1-single-vnet
./deploy.ps1
```

The following resources will be deployed under `rg-norwayeast-pdnsr-labs-s1`:

| Resource | Type |
|----------|------|
| `vnet-single-norwayeast` | Virtual Network (10.10.0.0/24) |
| `vnet-onprem-norwayeast` | Virtual Network (10.10.1.0/24) |
| `pdnsr-norwayeast` | Private DNS Resolver |
| `vm-workload-norwayeast` | Linux VM (B1s, Ubuntu 22.04) |
| `vm-onprem-norwayeast` | Linux VM (B1s, Ubuntu 22.04) with BIND9 |
| `bastion-norwayeast` | Azure Bastion (Basic) |
| `pip-bastion-norwayeast` | Public IP for Bastion |
| `sa<unique>` | Storage Account |
| `pe-blob-norwayeast` | Private Endpoint (Blob storage) |
| `privatelink.blob.core.windows.net` | Private DNS Zone |

### Network topology

```
10.10.0.0/24 (vnet-single-norwayeast)
├── subnet-inbound      10.10.0.0/28    ← DNS Resolver inbound endpoint
├── subnet-outbound     10.10.0.16/28   ← DNS Resolver outbound endpoint
├── AzureBastionSubnet  10.10.0.64/26   ← Azure Bastion
├── subnet-workload     10.10.0.128/26  ← vm-workload-norwayeast
└── subnet-pe           10.10.0.192/26  ← Private Endpoint (Storage)

10.10.1.0/24 (vnet-onprem-norwayeast, peered)
└── subnet-onprem       10.10.1.0/24    ← vm-onprem-norwayeast
```

### On-prem DNS server

`vm-onprem-norwayeast` is pre-configured with BIND9 and serves the `onprem.local` zone with these records:

| Record | IP |
|--------|----|
| `app.onprem.local` | vm-onprem private IP |
| `db.onprem.local` | 10.0.0.10 (synthetic) |

## Task #3 - Verify deployment and note IP addresses

Get the DNS Resolver inbound endpoint IP (needed in lab-02):

```powershell
az dns-resolver inbound-endpoint list `
  --dns-resolver-name pdnsr-norwayeast `
  --resource-group rg-norwayeast-pdnsr-labs-s1 `
  --query '[0].ipConfigurations[0].privateIpAddress' `
  -o tsv
```

Expected result: `10.10.0.4` (first available IP in the inbound subnet)

Get VM private IP addresses:

```powershell
# Workload VM
az vm show -d -g rg-norwayeast-pdnsr-labs-s1 -n vm-workload-norwayeast --query privateIps -o tsv

# On-prem VM (also the DNS server IP)
az vm show -d -g rg-norwayeast-pdnsr-labs-s1 -n vm-onprem-norwayeast --query privateIps -o tsv
```

| VM | Expected IP |
|----|-------------|
| `vm-workload-norwayeast` | 10.10.0.132 |
| `vm-onprem-norwayeast` | 10.10.1.4 |

Get the Storage Account FQDN (needed in labs 02–03):

```powershell
$saName = az storage account list -g rg-norwayeast-pdnsr-labs-s1 --query '[0].name' -o tsv
Write-Host "Storage FQDN: ${saName}.blob.core.windows.net"
```

## Task #4 - Verify connectivity via Bastion

Connect to `vm-workload-norwayeast`:

1. In Azure Portal, navigate to `vm-workload-norwayeast`
2. Click **Connect** → **Bastion**
3. Enter username `iac-admin` and password `fooBar123!`
4. Click **Connect**

From the workload VM, verify connectivity to the on-prem VM:

```bash
ping 10.10.1.4
```

Verify `dig` and `curl` are installed:

```bash
dig --version
curl --version
```

You are now ready for [lab-02](../lab-02/index.md).
