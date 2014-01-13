winston = require 'winston'

config = require('config').log

transports = []

if config
	if config.console and config.console.enabled
		transports.push new winston.transports.Console
			level: config.console.level or 'info'

	if config.sentry and config.sentry.enabled
		Sentry = require 'winston-sentry'

		transports.push new Sentry
			level: 'warn'
			dsn: config.sentry.dsn

module.exports = new winston.Logger
	transports: transports