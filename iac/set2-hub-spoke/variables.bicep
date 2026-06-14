@export()
func getResourcePrefix(location string) string => '${location}-pdnsr-labs'

@export()
var hubAddressRange = '10.11.0.0/24'

@export()
var onpremAddressRange = '10.11.3.0/24'

@export()
var adminUsername = 'iac-admin'

@export()
var adminPassword = 'fooBar123!'
