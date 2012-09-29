fs = require 'fs'
validate = require('json-schema').validate
cfile = new require './fileops.coffee'
filename = "/etc/udhcpd.conf"

@db = db =
    dhcp: require('dirty') '/tmp/dhcp.db'

db.dhcp.on 'load', ->
    console.log 'loaded dhcp.db'
    db.dhcp.forEach (key,val) ->
        console.log 'found ' + key

@lookup = lookup = (id) ->
    console.log "looking up config ID: #{id}"
    entry = db.dhcp.get id
    if entry
        if routerschema?
            console.log 'performing schema validation on retrieved config entry'
            result = validate entry, routerschema
            console.log result
            return new Error "Invalid config retrieved: #{result.errors}" unless result.valid

        return entry
    else
        return new Error "No such config ID: #{id}"

@include = ->
    services = require './services'

    loadService = ->
        result = services.lookup @params.id
        unless result instanceof Error
            @request.service = result
            @next()
        else
            return @next result

    # dhcpschema for dhcp configuration validation
    dhcpschema = 
        name: "dhcp"
        type: "object"
        additionalProperties: false
        properties:
            start:              {"type":"string", "required":true}
            end:                {"type":"string", "required":true}
            interface:          {"type":"string", "required":false}
            max_leases:         {"type":"number", "required":false}
            remaining:          {"type":"string", "required":false}
            auto_time:          {"type":"number", "required":false}
            decline_time:       {"type":"number", "required":false}
            conflict_time:      {"type":"number", "required":false}
            offer_time:         {"type":"number", "required":false}
            min_lease:          {"type":"number", "required":false}
            lease_file:         {"type":"string", "required":false}
            pidfile:            {"type":"string", "required":false}
            notify_file:        {"type":"string", "required":false}
            siaddr:             {"type":"string", "required":false}
            sname:              {"type":"string", "required":false}
            boot_file:          {"type":"string", "required":false}
            subnet:             {"type":"string", "required":false}
            domain:             {"type":"string", "required":false}
            lease:              {"type":"number", "required":false}

    # addrschema for address validation
    addrschema = 
        name: "address"
        type: "object"
        additionalProperties: false
        properties:
            address:             {"type":"string", "required":true}

    routerschema = 
        name: "dhcp"
        type: "object"
        additionalProperties: false
        properties:
            id:         { type: "string", required: true }
            filename:   { type: "string", required: false}
            address:
                items:  { type: "string" }



    # Function to validate the dhcp configuration with dhcpschema
    validateDhcp = ->
        console.log 'performing dhcpschema validation on incoming service JSON'
        result = validate @body, dhcpschema
        console.log result
        return @next new Error "Invalid service dhcp posting!: #{result.errors}" unless result.valid
        @next()

    # Function to validate the dddress with addrschema
    validateAddress = ->
        console.log 'performing addrschema validation on incoming service JSON'
        result = validate @body, addrschema
        console.log result
        return @next new Error "Invalid address posting!: #{result.errors}" unless result.valid
        @next()

    validateRouter = ->
        console.log 'performing schema validation on incoming config validation JSON'
        result = validate @body, routerschema
        console.log result
        return @next new Error "Invalid service dhcp posting!: #{result.errors}" unless result.valid
        @next()
    
    # Function to create config file and write or append to the config file 
    writeConfig = (config) ->
        console.log 'inside writeConfig'
        console.log "updating the dhcp config to #{filename}..."
        cfile.fileExists filename, (result) ->
           unless result instanceof Error
               fs.createWriteStream(filename, flags: "a").write config
           else
               cfile.createFile filename, (result) ->
                  return result if result instanceof Error

               cfile.updateFile filename, config, (result) ->
                  return result if result instanceof Error
        return { "result": "success" }

    # Function to create config file and write to the config file
    addRouter = (config, filename, id, body, callback) ->
        cfile.createFile filename, (result) ->
           return result if result instanceof Error

        cfile.updateFile filename, config, (result) ->
           return result if result instanceof Error

         try
           db.dhcp.set id, body, ->
              console.log "#{id} added to dhcp service configuration"
              console.log body
           callback({result: true })
         catch err
           callback(err)
     
    @post '/network/dhcp', validateDhcp, ->
       console.log 'inside endpoint /network/dhcp'
       config = ''
       for key, val of @body
           switch (typeof val)
               when "number", "string"
                   config += key + ' ' + val + "\n"
               when "boolean"
                   config += key + "\n"

       cfile.createFile filename, (result) ->
           return result if result instanceof Error
       cfile.updateFile filename, config, (result) ->
           return result if result instanceof Error
       @send {"result":"success"}       

#    @post '/network/dhcp/router', validateAddress, ->
#       console.log "inside endpoint router"
#       config = ''
#       for key, val of @body
#         switch (typeof val)
#           when "string"
#             config += 'option router' + ' ' + val + "\n"
#       result = writeConfig(config)
#       @send result

    @post '/network/dhcp/router', validateRouter, ->
       console.log 'inside endpoint router'
       config = ''
       for key, val of @body
            switch (typeof val)
                when "object"
                    if val instanceof Array
                        for i in val
                            config += "option router #{i}\n" if key is "address"
       id = @body.id
       body = @body

       if @body.filename
            filename = "/config/dhcp/#{@body.filename}"
       else
            filename = "/config/dhcp/filename"
       addRouter config, filename, id, body, (result) ->
            return result if result instanceof Error
       @send { "result" : "success"}    

    @post '/network/dhcp/timesvr', validateAddress, ->
       console.log "inside endpoint time server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option timesvr' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result
 
    @post '/network/dhcp/namesvr', validateAddress, ->
       console.log "inside endpoint name server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option namesvr' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result

    @post '/network/dhcp/dns', validateAddress, ->
       console.log "inside endpoint dns"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option dns' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result

    @post '/network/dhcp/logsvr', validateAddress, ->
       console.log "inside endpoint log server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option logsvr' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result
 
    @post '/network/dhcp/cookiesvr', validateAddress, ->
       console.log "inside endpoint cookie server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option cookiesvr' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result

    @post '/network/dhcp/lprsvr', validateAddress, ->
       console.log "inside endpoint lpr server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option lprsvr' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result

    @post '/network/dhcp/ntpsvr', validateAddress, ->
       console.log "inside endpoint ntp server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option ntpsvr' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result

    @post '/network/dhcp/wins', validateAddress, ->
       console.log "inside endpoint wins"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option wins' + ' ' + val + "\n"
       result = writeConfig(config)
       @send result

    @get '/network/:id/dhcp', loadService, ->
        @send @request.service
