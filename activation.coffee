fs = require 'fs'

serial-key = ''
module.exports = class activation
    constructor = (nexusserver, nexusport, activationserver, activationport) ->
        @nexusserver = nexusserver
        @nexusport = nexusport
        @activationserver = activationserver
        @activationport = activationport
        @serialkey = ''
        @configpath = "/registration/#{@serialkey}/config"


    activate = ->
        try
            exec "/config/activation/bootstrap.sh"
        catch err
            console.log 'Error in activating the CPE'
        return fileExists("/var/run/activated")

    fetchResponse = (url, method, body, callback) ->
        url = require 'url'
        parsedurl = url.parse "url", 0, true
        http = require 'http'
        options.host = parsedurl.host
        options.port = parsedurl.port

        #Get initial config from partner
        options.method = method
        options.path = parsedurl.path
        req = http.request options, (res) ->
            console.log 'got response'
          
        req.on 'error', (error) ->
           console.log error
           return Error error
      
        console.log JSON.stringify(body)
        req.setHeader "Content-Type", "application/json"
        req.write JSON.stringify(body)
        
        buf = new Buffer(102400)
        size = 0
        statusCode = 200
        req.on 'response', (resp) ->
            statusCode = resp.statusCode

            resp.on 'data', (chunk) ->
                console.log "response rcvd "
                respstr = chunk.toString "utf-8", 0, chunk.length

                chunk.copy(buf, size, 0 , chunk.length)
                size += chunk.length
            resp.on 'end', () ->
                respString  = buf.toString "utf-8", 0, size
                console.log 'size of buffer is :' + respString.length
                console.log 'status code is: ' + statusCode
                callback (statusCode, respString)
        req.end()
        
    fetchInitConfig = (serialkey, callback) ->
        @fetchResponse "http://#{@partnerserver}:#{@partnerport}#{@configurepath}", "GET", " " , (statusCode, respString) ->
            if statusCode != 200
                return new Error respString
            
            respjson = JSON.parse(respString)
            #Parse through the recvd response and call cloudflash APIs
            for key, val of respjson
                switch (typeof val)
                    when "object"
                        if val instanceof Array
                            for i in val
                                @fetchResponse "#{i.url}", "#{i.method}", "#{i.body}", (statusCode, respString) ->
                                    if statusCode != 200
                                        console.log "failed to process the url: " + "#{i.method} #{i.url}"  
                                        callback (statusCode, respString)
                                        
        
            callback (200, {result:success})
        






#{@app} = require('zappajs') 8080, ->
        #    @configure =>
        #        @use 'bodyParser', 'methodOverride', @app.router, 'static'
        #        @set 'basepath': '/v1.0'

        #    @configure
        #development: => @use errorHandler: {dumpExceptions: on, showStack: on}
        #production: => @use 'errorHandler'

        #    @post '/activation/serial-key' : ->
        #cfile.createFile("/config/activation/serial-key")
        #serial-key = @body.serialkey
        #cfile.updateFile(serial-key, "/config/activation/serial-key")
        #@send {result:success}

        #    @post '/activation/restart' : ->
        #try
        #    exec "rm -rf /var/run/activated"
        #catch err
        #    @send new Error "could not reactivate"

        #result = activate(@body.serialkey)
        #@send new Error if result instanceof Error
        #@send {result:success}
            


    





