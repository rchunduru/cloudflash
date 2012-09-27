fs = require 'fs'
validate = require('json-schema').validate
exec = require('child_process').exec
path = require 'path'    
    
dbnwk = 
        main: require('dirty') '/tmp/network.db'

classfile = new require './fileops.coffee'
cfile = new classfile
filename = "/etc/network/interfaces.tmp"

#Test schema to validate incoming JSON
nwkschema =
        name: "network"
        type: "object"
        additionalProperties: false
        properties: 
             static:
                 items: {"type":"object", required: true}


@include = ->
    validateschemaNwk = ->
        console.log @body
        console.log 'performing schema validation on incoming network JSON'
        result = validate @body, nwkschema
        console.log result
        return @next new Error "Invalid service posting!: #{result.errors}" unless result.valid
        @next()    

    # helper routine to loop through nested input json
    loopthrow = (obj,k,devName) ->
        config = ''
        for key, val of obj
            if val instanceof Array
              for i in val
                if typeof i is "object"
                  config += "\t#{k} #{key} "
                  for k,v of i
                    config += "#{k} #{v} "
              
                  config += "dev #{devName} \n"             
        
        return config                

    #Routine to get network config from input json
    generateNwkConfig = (obj) ->
        config = ''
        devName = ''
        for key, val of obj
            switch (typeof val)
                when "object"
                    if val instanceof Array                     
                        for i in val
                            if typeof i is "object"                              
                              for k, j of i
                                if typeof j isnt "object"
                                  if k.match /device/
                                      devName = j
                                      config += "auto #{j} \n"
                                      config += "iface #{j} inet #{key} \n"
                                  else
                                     config += "\t#{k} #{j} \n"                                 
                                else                                  
                                  config += loopthrow(j,k,devName)                                                
                        
                when "number", "string"
                    config += "#{key} #{val} \n"
                when "boolean"
                    config += key + "\n"
        console.log "config: " + config
        return config

    
    #Routine to write into database key as device name and val as object
    writeNwkConfigDb = (body,callback) ->         
        devName = ''
        try
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
          callback({"result": "success"})      
        catch err
          console.log  "Unable to write database dbnwk"
          callback (err)        
               

    @post '/network/interfaces', validateschemaNwk,  ->
        #filename = "/etc/network/interfaces.tmp"
        cfile.createFile filename, (result) ->
            return result if result instanceof Error 
             
        config = ''
        config = generateNwkConfig(@body)
        
        cfile.updateFile config, filename, (result) ->
            return result if result instanceof Error     
              
        writeNwkConfigDb @body, (result) ->
            return result if result instanceof Error       
        @send {"result":"success"}

    @get '/network/interfaces' : ->
        res = { 'network': [] }
        dbnwk.main.forEach (key,val) ->
            console.log 'found ' + key
            res.network.push key
        console.log res
        @send res

    @get "/network/interfaces/:ifid" : ->
        res = { "device" : "", "status" : "", "txbytes" : "", "rxbytes" : "" }
        
        result = dbnwk.main.get @params.ifid
        if result
           exec "ifconfig #{@params.ifid}", (error, stdout, stderr) =>
             unless error
               
               arrStr = stdout.split "\n"
               for i in arrStr
                 if i.match /RX bytes/ or /TX bytes/
                   arrStrSplt = i.split "  "
                   for j in arrStrSplt                     
                     arrStrsplt1 = j.split "("
                     
                     if arrStrsplt1[0].match /RX bytes:/
                       strRx = arrStrsplt1[0]
                       strRx = strRx.replace /^\s+|\s+$/g, ""
                       strRx = strRx.replace /RX bytes:/g, ""
                       res.rxbytes = strRx
                     else if arrStrsplt1[0].match /TX bytes:/
                       strTx = arrStrsplt1[0]
                       strTx = strTx.replace /^\s+|\s+$/g, ""
                       strTx = strTx.replace /TX bytes:/g, ""
                       res.txbytes = strTx
                 else if i.match /UP /
                     res.status = "active"
                 else if i.match /DOWN /
                     res.status = "down"
                              
               
               res.device = @params.ifid
             else
               return @next new Error error 
             @send res      
        else
           return @next new Error "No such interface ID: #{@params.ifid}"

    @del '/network/interfaces/:ifid': -> 
        result = dbnwk.main.get @params.ifid
        config = ''
        if result
          dbnwk.main.rm @params.ifid, =>
            console.log "removed interface ID: #{@params.ifid}"
            dbnwk.main.forEach (key,val) ->
              console.log 'found ' + key   
              jsnval = {"static" : [val]}         
              config += generateNwkConfig(jsnval) 
             
            console.log "config: " + config 
            #filename = "/etc/network/interfaces.tmp"       
            cfile.updateFile config, filename, (result) ->
              return result if result instanceof Error         
          @send {"result":"success"} 
        else            
          return @next new Error "No such interface ID: #{@params.ifid}"
 
    

    


