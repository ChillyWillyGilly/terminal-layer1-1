# Layer1 shared entry point

# parse the options in advance
commander = require 'commander'

commander
	.option('-m, --mode [mode]', 'run this server mode', 't-npm')
	.parse(process.argv)

# initialize logging
logger = require './lib/logger.iced'

# check the runtime mode
modes = require('config').modes

if not modes
	logger.error 'no modes defined in configuration'
	return

mode = commander.mode

if not modes[mode]
	logger.error 'no such mode: %s', mode
	return

# do whatever needs to be done for the mode
modeTypes =
	transport: (mode) ->
		# this mode just includes the transport
		require "./transports/#{ mode.transport }.iced"

mode = modes[mode]

if not mode.type of modeTypes
	logger.error 'no type defined for mode %s', mode
	return

modeTypes[mode.type] mode