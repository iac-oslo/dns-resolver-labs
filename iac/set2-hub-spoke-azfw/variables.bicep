@export()
func getResourcePrefix(location string) string => '${location}-pdnsr-labs'

@export()
var hubAddressRange = '10.12.0.0/23'

@export()
var onpremAddressRange = '10.12.4.0/24'

@export()
var adminUsername = 'iac-admin'

@export()
var adminPassword = 'fooBar123!'
