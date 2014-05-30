auth = require '../auth-shared.iced'

anonymousSid = 1

module.exports = (data, state) ->
    if data.licenseKey != ''
        auth.handleAuthReply state, 1

    # handy reply function
    token = ''
    npid = [ 0x1200001, anonymousSid ]

    anonymousSid++

    if anonymousSid > 200000000
        anonymousSid = 1

    result = 0

    auth.handleAuthReply state, result, npid, token
