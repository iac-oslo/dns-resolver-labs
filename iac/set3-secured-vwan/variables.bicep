@export()
func getResourcePrefix(location string) string => '${location}-pdnsr-labs'

@export()
var vwanHubAddressRange = '10.13.0.0/23'

@export()
var connectivityAddressRange = '10.13.2.0/23'

@export()
var spokeAddressRange = '10.13.4.0/24'

@export()
var onpremAddressRange = '10.13.5.0/24'

@export()
var adminUsername = 'iac-admin'

@export()
var adminPassword = 'fooBar123!'
