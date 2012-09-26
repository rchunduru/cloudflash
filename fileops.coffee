module.exports = class fileops
    createFile = (filename, callback) ->
        try
            dir = path.dirname filename
            unless path.existsSync dir
                console.log 'no path exists'
                exec "mkdir -p #{dir}", (error, stdout, stderr) =>
                    unless error
                        console.log 'created path'
                        exec "touch #{filename}"
            else
                console.log 'path exists'
                exec "touch #{filename}"
            callback({result: success})
        catch err
            console.log  "Unable to write configuration file into #{filename}"
            callback (err)

    updateFile = (config, filename) ->
        fs.writeFileSync filename, config

    fileExists = (filename, callback) ->
        stats = fs.existsSync filename
        if stats.isFile
            callback ({result:success})
        else
            console.log 'File does not exist'
            err = new Error "File does not exist"
            callback (err)
     
