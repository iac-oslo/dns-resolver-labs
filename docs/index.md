# Working with Azure Private DNS Resolver

This workshop covers practical hands-on labs for Azure Private DNS Resolver. You will learn how to deploy and configure DNS Resolver across multiple network topologies and use-cases.

## Use-cases covered

| Lab | Topology | Scenario |
|-----|----------|----------|
| [lab-02](labs/lab-02/index.md) | Single VNet | Resolver resolves Private Endpoint |
| [lab-03](labs/lab-03/index.md) | Single VNet | Resolver forwards DNS to on-prem workload |
| [lab-05](labs/lab-05/index.md) | Hub-Spoke + Azure Firewall | AzFW DNS Proxy + Resolver resolves PE |
| [lab-06](labs/lab-06/index.md) | Hub-Spoke + Azure Firewall | AzFW DNS Proxy + Resolver forwards to on-prem DNS |

## Workshop structure

Labs are organized into two infrastructure sets. Deploy each set before running the corresponding labs, then clean up to save costs.

| IaC Set | Labs | Cost (3h) |
|---------|------|-----------|
| Set 1 — Single VNet | lab-01, lab-02, lab-03 | ~$1.88 |
| Set 2 — Hub-Spoke + AzFW | lab-04, lab-05, lab-06 | ~$2.94 |

## Key concepts

**Azure Private DNS Resolver** — a managed service that enables DNS queries to flow between Azure and on-premises without requiring custom DNS VMs. It provides:

- **Inbound endpoints** — receive DNS queries from on-premises or other networks
- **Outbound endpoints** — forward DNS queries to external DNS servers
- **DNS Forwarding Rulesets** — rules that define which domains are forwarded and where

**Private Endpoint** — a network interface that connects a service (e.g., Azure Storage) to a VNet using a private IP. Resolution requires a Private DNS Zone.

**Azure Firewall as DNS Proxy** — routes DNS queries from spoke VMs through the firewall before reaching the DNS Resolver, centralizing DNS traffic for inspection and logging.
