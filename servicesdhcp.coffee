# validation is used by other modules
validate = require('json-schema').validate

@db = db = require('dirty') '/tmp/cloudflash.db'

db.on 'load', ->
    console.log 'loaded cloudflash.db'
    db.forEach (key,val) ->
        console.log 'found ' + key

@lookup = lookup = (id) ->
    console.log "looking up service ID: #{id}"
    entry = db.get id
    if entry

        if schema?
            console.log 'performing schema validation on retrieved service entry'
            result = validate entry, schema
            console.log result
            return new Error "Invalid service retrieved: #{result.errors}" unless result.valid

        return entry
    else
        return new Error "No such service ID: #{id}"

@include = ->
    uuid = require('node-uuid')
    webreq = require 'request'
    fs = require 'fs'
    path = require 'path'
    exec = require('child_process').exec
    url = require('url')
    
    validate = require('json-schema').validate

    services = require './services'
    
    # testing dhcp validation with dhcp schema
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

    
    addrschema = 
        name: "address"
        type: "object"
        additionalProperties: false
        properties:
            address:             {"type":"string", "required":true}


    validateDhcp = ->
        console.log 'performing dhcpschema validation on incoming service JSON'
        result = validate @body, dhcpschema
        console.log result
        return @next new Error "Invalid service dhcp posting!: #{result.errors}" unless result.valid
        @next()


    validateAddress = ->
        console.log 'performing addrschema validation on incoming service JSON'
        result = validate @body, addrschema
        console.log result
        return @next new Error "Invalid address posting!: #{result.errors}" unless result.valid
        @next()


    writeConfig = (config) ->
        console.log 'inside writeConfig'
        console.log config
        filename = '/home/maltesh/udhcpd.conf'
        try
           console.log "updating the dhcp config to #{filename}..."
           dir = path.dirname filename
           unless path.existsSync dir
             exec "mkdir -p #{dir}", (error, stdout, stderr) =>
               unless error
                    fs.writeFileSync filename, config
           else
             fs.createWriteStream(filename, flags: "a").write config
           return { result: true }
        catch err
           return { result: false }



    # helper routine for retrieving service data from dirty db
    loadService = ->
        result = lookup @params.id
        unless result instanceof Error
            @request.service = result
            @next()
        else
            return @next result    
    

    @post '/network/dhcp', validateDhcp, ->
       console.log 'inside endpoint /network/dhcp'
       config = ''
       for key, val of @body
           switch (typeof val)
               when "number", "string"
                   config += key + ' ' + val + "\n"
               when "boolean"
                   config += key + "\n"
       console.log config
       
       filename = '/home/maltesh/udhcpd.conf'
       try
            console.log "write dhcp config to #{filename}..."
            dir = path.dirname filename
            unless path.existsSync dir
                exec "mkdir -p #{dir}", (error, stdout, stderr) =>
                    unless error
                        fs.writeFileSync filename, config
            else
                fs.writeFileSync filename, config

            @send { result: true }
       catch err
            @next new Error "Unable to write configuration into #{filename}!"


    @post '/network/dhcp/router', validateAddress, ->
       console.log "inside endpoint router"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option router' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result


    @post '/network/dhcp/timesvr', validateAddress, ->
       console.log "inside endpoint time server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option timesvr' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result
 
  
    @post '/network/dhcp/namesvr', validateAddress, ->
       console.log "inside endpoint name server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option namesvr' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result


    @post '/network/dhcp/dns', validateAddress, ->
       console.log "inside endpoint dns"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option dns' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result

    
    @post '/network/dhcp/logsvr', validateAddress, ->
       console.log "inside endpoint log server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option logsvr' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result
 

    @post '/network/dhcp/cookiesvr', validateAddress, ->
       console.log "inside endpoint cookie server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option cookiesvr' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result


    @post '/network/dhcp/lprsvr', validateAddress, ->
       console.log "inside endpoint lpr server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option lprsvr' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result


    @post '/network/dhcp/ntpsvr', validateAddress, ->
       console.log "inside endpoint ntp server"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option ntpsvr' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result


    @post '/network/dhcp/wins', validateAddress, ->
       console.log "inside endpoint wins"
       config = ''
       for key, val of @body
         switch (typeof val)
           when "string"
             config += 'option wins' + ' ' + val + "\n"
       result = writeConfig(config)
       console.log result
       @send result


    @get '/network/:id/dhcp', loadService, ->
        console.log @request.service
        @send @request.service
