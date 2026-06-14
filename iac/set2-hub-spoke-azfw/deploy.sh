#!/usr/bin/env bash
set -euo pipefail

start=$(date +%s)

location='norwayeast'

echo "Deploying DNS Resolver Labs - Set 3 (Hub-Spoke + Azure Firewall) into $location..."
deployment_name="pdnsr-labs-s3-$(date -u +%Y%m%dT%H%M%S%3NZ)"
az deployment sub create -l "$location" --template-file main.bicep -p parLocation="$location" -n "$deployment_name"

end=$(date +%s)
echo "Deployment time: $((end - start))s"
