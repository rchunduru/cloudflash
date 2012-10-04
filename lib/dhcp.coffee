fs = require 'fs'
validate = require('json-schema').validate
cfile = new require './fileops.coffee'
# filename = '/home/maltesh/udhcpd_test.conf'
filename = "/etc/udhcpd.conf"
uuid = require('node-uuid')

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
            option:             
               items:           {"type":"string"}

    # addrschema for address validation
    addrschema = 
        name: "dhcp"
        type: "object"
        additionalProperties: false
        properties:
            optionparam:        {"type":"string", "required":"true"}
            address:
                items:          { type: "string" }

    # Function to validate the dhcp configuration with dhcpschema
    validateDhcp = ->
        console.log 'performing dhcpschema validation on incoming service JSON'
        result = validate @body, dhcpschema
        console.log result
        return @next new Error "Invalid service dhcp posting!: #{result.errors}" unless result.valid
        @next()

    # Function to validate the address with addrschema
    validateAddress = ->
        console.log 'performing schema validation on incoming config validation JSON'
        result = validate @body, addrschema
        console.log result
        return @next new Error "Invalid service dhcp posting!: #{result.errors}" unless result.valid
        @next()
    
    # writeConfig: Function to add/modify configuration and update the dhcp db with id 
    writeConfig = (config, id, body) ->
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
        try
           db.dhcp.set id, body, ->
              console.log "#{id} added to dhcp service configuration"
           return { "result": "success" }
        catch err
           return { "result" : "failed" }

    # removeConfig: Function to remove configuration with given id
    removeConfig = (id, optionvalue) ->
        console.log 'inside removeConfig'
        entry = db.dhcp.get id
        if !entry
            return { "deleted" : "no data to delete"}
        configList = []
        if optionvalue=='subnet'
          optionvalue = ''
          for key, val of entry
            switch (typeof val)
                when "number", "string"
                   config = key + ' ' + val
                   configList.push(config)
                when "object"
                   if val instanceof Array
                        for i in val
                            config = "#{key} #{i}" if key is "option"
                            configList.push(config)
        else     
          configList = entry.address
        newconfig = ''
        cfile.readFile filename, (result) ->
            throw new Error result if result instanceof Error
            for line in result.split '\n'
                j = 0
                flag = 0
                while j < configList.length
                    config = optionvalue
                    config += configList[j]
                    if line==config
                       flag = 1
                       j++
                    else
                       j++
                if flag == 0
                   newconfig += line + '\n'
            try   
               db.dhcp.rm id, ->
                  console.log "removed config id: #{id}"
            catch err
               return { "deleted" : "failed"}

            cfile.createFile filename, (result) ->
                return result if result instanceof Error

            cfile.updateFile filename, newconfig, (result) ->
                return result if result instanceof Error
        return { "deleted" : "success"}


    @post '/network/dhcp/subnet', validateDhcp, ->
       console.log 'inside @post /network/dhcp/subnet'
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body
           switch (typeof val)
               when "number", "string"
                   config += key + ' ' + val + "\n"
               when "boolean"
                   config += key + "\n"
               when "object"
                   if val instanceof Array
                        for i in val
                            config += "#{key} #{i}\n" if key is "option"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/subnet/:id', ->
        console.log "inside @del /network/dhcp/subnet/#{@params.id}"
        id = @params.id
        optionvalue = 'subnet'
        result = removeConfig(id, optionvalue)
        @send result

    @post '/network/dhcp/router', validateAddress, ->
       console.log "inside @post /network/dhcp/router"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id  
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option router' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/router/:id', ->
        console.log "inside @del /network/dhcp/router/#{@params.id}"
        id = @params.id
        optionvalue = 'option router '
        result = removeConfig(id, optionvalue)
        @send result

    @post '/network/dhcp/timesvr', validateAddress, ->
       console.log "inside @post /network/dhcp/timesvr"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id         
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option timesvr' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/timesvr/:id', ->
        console.log "inside @del /network/dhcp/timesvr/#{@params.id}"
        id = @params.id
        optionvalue = 'option timesvr '
        result = removeConfig(id, optionvalue)
        @send result

    @post '/network/dhcp/namesvr', validateAddress, ->
       console.log "inside @post /network/dhcp/namesvr"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option namesvr' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/namesvr/:id', ->
        console.log "inside @del /network/dhcp/namesvr/#{@params.id}"
        id = @params.id
        optionvalue = 'option namesvr '
        result = removeConfig(id, optionvalue)
        @send result

    @post '/network/dhcp/dns', validateAddress, ->
       console.log "inside @post /network/dhcp/dns"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option dns' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/dns/:id', ->
        console.log "inside @del /network/dhcp/dns/#{@params.id}"
        id = @params.id
        optionvalue = 'option dns '
        result = removeConfig(id, optionvalue)
        @send result
 
    @post '/network/dhcp/logsvr', validateAddress, ->
       console.log "inside @post /network/dhcp/logsvr"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option logsvr' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/logsvr/:id', ->
        console.log "inside @del /network/dhcp/logsvr/#{@params.id}"
        id = @params.id
        optionvalue = 'option logsvr '
        result = removeConfig(id, optionvalue)
        @send result
 
    @post '/network/dhcp/cookiesvr', validateAddress, ->
       console.log "inside @post /network/dhcp/cookiesvr"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option cookiesvr' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/cookiesvr/:id', ->
        console.log "inside @del /network/dhcp/cookiesvr/#{@params.id}"
        id = @params.id
        optionvalue = 'option cookiesvr '
        result = removeConfig(id, optionvalue)
        @send result

    @post '/network/dhcp/lprsvr', validateAddress, ->
       console.log "inside @post /network/dhcp/lprsvr"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option lprsvr' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/lprsvr/:id', ->
        console.log "inside @del /network/dhcp/lprsvr/#{@params.id}"
        id = @params.id
        optionvalue = 'option lprsvr '
        result = removeConfig(id, optionvalue)
        @send result

    @post '/network/dhcp/ntpsrv', validateAddress, ->
       console.log "inside @post /network/dhcp/ntpsrv"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option ntpsrv' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/ntpsrv/:id', ->
        console.log "inside @del /network/dhcp/ntpsrv/#{@params.id}"
        id = @params.id
        optionvalue = 'option ntpsrv '
        result = removeConfig(id, optionvalue)
        @send result
    
    @post '/network/dhcp/wins', validateAddress, ->
       console.log "inside @post /network/dhcp/wins"
       id = uuid.v4()
       return @next new Error "Duplicate config ID detected!" if db.dhcp.get id
       config = ''
       for key, val of @body.address
         switch (typeof val)
           when "string"
             config += 'option wins' + ' ' + val + "\n"
       body = @body
       result = writeConfig(config, id, body)
       @send result

    @del '/network/dhcp/wins/:id', ->
        console.log "inside @del /network/dhcp/wins/#{@params.id}"
        id = @params.id
        optionvalue = 'option wins '
        result = removeConfig(id, optionvalue)
        @send result

    @get '/network/dhcp/:id', ->
        console.log "inside @get /network/dhcp/#{@params.id}" 
        entry = db.dhcp.get @params.id 
        if entry 
           @send entry
        else
           @send {"information":"no data"}
  
