resource_manifest_version "44febabe-d386-4d18-afbe-5e627f4af937"

description 'pip Car Thief'

author 'Pipo'

server_scripts {
	'locales/en.lua',
	'config.lua',
	'server/server.lua'
}

client_scripts {
	'@progressBars/client.lua',
	'@menuv/menuv.lua',
	'locales/en.lua',
	'config.lua',
	'client/utils.lua',
	'client/client.lua'
}

shared_script '@qb-core/import.lua'

dependencies {
	'menuv'
}