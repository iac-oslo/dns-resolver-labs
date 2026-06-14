@export()
func getResourcePrefix(location string) string => '${location}-pdnsr-labs'

@export()
var singleVnetAddressRange = '10.10.0.0/24'

@export()
var resolverVnetAddressRange = '10.10.2.0/26'

@export()
var onpremVnetAddressRange = '10.10.1.0/24'

@export()
var adminUsername = 'iac-admin'

@export()
var adminPassword = 'fooBar123!'
