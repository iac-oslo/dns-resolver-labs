# lab-07 - Cleaning up resources

This is the most important part of the workshop. Delete all lab resources to avoid unexpected charges.

!!! warning "Azure Firewall and Bastion cost money even when idle"
    Azure Firewall Basic costs ~$0.33/hr and Bastion Basic costs ~$0.19/hr. A forgotten Set 2 or Set 3 deployment left running for 12 hours can cost ~$10–12.

## Task #1 - Delete all lab resource groups

Run the following commands to delete all resource groups. The `--no-wait` flag returns immediately; deletion runs in the background.

```powershell
az group delete --name rg-norwayeast-pdnsr-labs-s1 --yes --no-wait
az group delete --name rg-norwayeast-pdnsr-labs-s2 --yes --no-wait
az group delete --name rg-norwayeast-pdnsr-labs-s3 --yes --no-wait
```

If you only completed some sets, only the resource groups that exist need to be deleted.

## Task #2 - Verify deletion

Check that the resource groups are gone (or in deleting state):

```powershell
az group list --query "[?contains(name, 'pdnsr-labs')].{name:name, state:properties.provisioningState}" -o table
```

Once deleted, no resources remain and billing stops.
