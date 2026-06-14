# Prerequisites

## Required tools

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) v2.50+
- [Bicep CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) v0.24+
- [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) 7.x+ (for deploy scripts)
- An Azure subscription with `Contributor` or `Owner` role

## Azure CLI login

```powershell
az login
az account show
```

If you have multiple subscriptions, set the correct one:

```powershell
az account set --subscription "<subscription-id>"
```

## Required az CLI extensions

```powershell
az extension add -n bastion
az extension add -n dns-resolver
```

## Resource provider registration

Run the following before deploying any lab set:

```powershell
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Resources
```

## Lab credentials

All VMs are deployed with the following credentials:

| Setting | Value |
|---------|-------|
| Username | `iac-admin` |
| Password | `fooBar123!` |

!!! warning
    These credentials are for lab use only. Do not use them in production environments.

## Connecting to VMs

All labs use **Azure Bastion Basic SKU** for VM access. Connect to VMs via:

1. Navigate to the VM in Azure Portal
2. Click **Connect** → **Bastion**
3. Enter `iac-admin` / `fooBar123!`
4. Click **Connect**

A browser-based SSH terminal opens in the Azure Portal.
