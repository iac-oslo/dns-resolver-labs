# Project Memory

## Deployment scripts

- **deploy.sh + deploy.ps1 parity** — both exist per set (`iac/set*/`); changes to one must be applied to both

## Azure / Bicep constraints

- **raw.githubusercontent.com URL format** — use `main/path` not `refs/heads/main/path` — latter returns 404
- **DNS resolver subnet delegation** — `subnet-inbound` and `subnet-outbound` must have `delegation: 'Microsoft.Network/dnsResolvers'` — redeployments fail when service association link exists without it
- **DNS resolver inbound endpoint output** — `reference(resourceId(...))` in Bicep outputs has no implicit dep on the module; use `existing` resource with `dependsOn: [modResolver]` to avoid race condition
- **CSE caching** — Azure CSE won't re-download a script if fileUris + commandToExecute are unchanged; need a fresh RG to pick up updated scripts at the same URL

## VM setup scripts (Ubuntu 22.04 Gen2)

- **bind9 systemctl alias** — Ubuntu 22.04 installs bind9 as `named.service`; use `systemctl enable --now named && systemctl restart named`, not `bind9`
- **Ubuntu universe repo** — `bind9utils` and `dnsutils` are in `universe`, not enabled by default on Azure Ubuntu 22.04 Gen2; enable with `software-properties-common` + `add-apt-repository -y universe` before install
- **apt transient failures** — add `apt-get clean` + `|| apt-get update -y` retry; Azure VMs occasionally serve corrupted `InRelease` files
