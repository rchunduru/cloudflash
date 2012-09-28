exec = require('child_process').exec
querystring = require('querystring')
url = require('url')
@include = ->
    handleProxyRequest = (cname, reqMethod, zappaparams, callback) ->
        serverpath = ''
        console.log zappaparams[0]
        for key, value in zappaparams[2...1]
            serverpath += "/#{key}"
        ipaddr = ''
        #To get IP address
        exec "sudo cat openvpn-status.log", (error, stdout, stderr) =>
            
            unless error
              arrStr = stdout.split "\n"
              for i in arrStr
                 console.log "here: " + i
                 if ipaddr is ''                 
                  if i.match cname
                   arripSplt = i.split ":"
                   strsplt = arripSplt[0]                 

                   strsplt = strsplt.replace cname , ""
                   strsplt = strsplt.replace "," , ""
                   ipaddr = strsplt 
            console.log "ipaddr: "+ ipaddr
            serverurl = "#{ipaddr}:8000/#{zappaparams}"
        #Fetch the destination using openvpn get userslist from the management tunnel
        #based on the commonname in the request
            console.log serverpath
            console.log serverurl

            webclient = new require './webclient.coffee'
            wclient = new webclient
            wclient.fetchResponse serverurl, reqMethod, @body, (statusCode, respString) ->
                callback statusCode, respString 


    @get '/webproxy/:cname/*' : ->
        #Fetch the IP address from the commonname
        zappasend = @send
        zappanext = @next        
        reqMethod = @request.method
        #getIP cname, @params, (result) ->
        #   console.log "result: " + result 
        #   zappasend {result:true}
        handleProxyRequest @params.cname, reqMethod, @params, (statusCode, respString) ->
            @send statusCode, respString

    @del '/webproxy/*' : ->
        handleProxyRequest (statusCode, respString) ->
            #@send statusCode, respString
    @post '/webproxy/*' : ->
        handleProxyRequest (statusCode, respString) ->
            #@send statusCode, respString
        



    

