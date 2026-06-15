$stopwatch = [System.Diagnostics.Stopwatch]::new()
$stopwatch.Start()

$location = 'norwayeast'

Write-Host "Deploying DNS Resolver Labs - Set 3 (Secured VWAN + Azure Firewall) into $location..."
$deploymentName = 'pdnsr-labs-s3-{0}' -f (-join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
az deployment sub create -l $location --template-file main.bicep -p parLocation=$location -n $deploymentName

$stopwatch.Stop()
Write-Host "Deployment time: " $stopwatch.Elapsed
