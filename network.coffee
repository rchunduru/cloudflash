networkstatus = ''
@include = ->
    fs = require 'fs'
    validate = require('json-schema').validate
    exec = require('child_process').exec
    path = require 'path'
    
    dbnwk =
       main: require('dirty') '/tmp/network.db'

    #Test schema to validate incoming JSON
    nwkschema =
        name: "network"
        type: "object"
        additionalProperties: false
        properties:
             static:
                 items: {"type":"object", required: true}

    validateschemaNwk = ->
        console.log @body
        console.log 'performing schema validation on incoming network JSON'
        result = validate @body, nwkschema
        console.log result
        return @next new Error "Invalid service posting!: #{result.errors}" unless result.valid
        @next()

    createFileNwk = (filename) ->
        try
            console.log "write network config to #{filename}..."
            dir = path.dirname filename
            unless path.existsSync dir
                exec "mkdir -p #{dir}", (error, stdout, stderr) =>
                    unless error
                        #console.log 'created path'
                        exec "touch #{filename}"
            else
                #console.log "path exists"
                exec "touch #{filename}"
            return {"result":"success"}
        catch err
            return new Error "Unable to write network configuration into #{filename}!"

    generateNwkConfig = (body) ->
        config = ''

        devName = ''
        for key, val of body
            switch (typeof val)
                when "object"
                    if val instanceof Array
                        for i in val
                            if typeof i is "object"
                              for k, j of i
                                 if typeof j is "object"
                                    for l, m of j
                                      if m instanceof Array
                                        for n in m
                                          config += "#{k} #{l}"
                                          for o, p of n
                                              config += " #{o} #{p} "
                                          config += "dev #{devName} \n"
                                 else
                                    if k.match /device/
                                      devName = j
                                      config += "auto #{j} \n"
                                      config += "iface #{j} inet #{key} \n"
                                    else
                                     config += "#{k} #{j} \n"
                
        #console.log "config main: " + configMain
        return config
    writeNwkConfigDb = (body) ->

        devName = ''
        for key, val of body
            switch (typeof val)
                when "object"
                    if val instanceof Array
                        for i in val
                            if typeof i is "object"
                              for k, j of i
                                 if typeof j isnt "object"
                                   if k.match /device/
                                      devName = j
                                      
                              dbnwk.main.set devName, i, ->
                                 console.log "network configuration saved"
                            
                
        
        return {"result":"success"}
    updateConfigFileNwk = (config, filename) ->
        fs.writeFileSync filename, config

    @post '/network/interfaces', validateschemaNwk,  ->
        filename = "/etc/network/interfaces.tmp"
        #result = createFileNwk(filename)
        #return result if Error  
        createFileNwk(filename)
        config = ''
        config = generateNwkConfig(@body)

        updateConfigFileNwk(config, filename)
        writeNwkConfigDb(@body)
        @send {"result":"success"}

    @get '/network/interfaces' : ->
        res = { 'network': [] }
        dbnwk.main.forEach (key,val) ->
            console.log 'found ' + key
            res.network.push key
        console.log res
        @send res
    @get '/network/interfaces/:id' : ->
        result = dbnwk.main.get @params.id
        console.log "result: " + result
        @send result #{"status": "#{networkstatus}"}

    



