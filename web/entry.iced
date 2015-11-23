# entry point for web service processes

logger = require('../lib/logger.iced')

# configuration reading
config = require('config').webServices

if not config
	logger.error 'no webServices section in config'
	process.exit 1

run = (mode) ->
	subset = mode.subset

	# if this isn't an array, make it one
	if not Array.isArray subset
		subset = [subset]

	# handlers
	services = []

	for entry in subset
		# check the subset
		if not config[entry]
			logger.error 'unconfigured subset %s in web service', subset
			process.exit 1

		if Array.isArray config[entry]
			services = services.concat(config[entry])
		else
			services.push(config[entry])

	# initialize Express on the web endpoint
	express = require 'express'
	app = express()

	# listen
	app.listen(mode.port or 3035)

	# include service handlers
	for service in services
		try
			ep = require "./#{ service }.iced"
			ep.initialize app
		catch e
			logger.error 'error initializing %s: %s', service, e.toString()

module.exports.run = run