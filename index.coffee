express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io').listen server

PORT = process.env.NODE_PORT || 8089

app.get '/', (req,res) ->
    res.sendFile __dirname + '/index.html'

server.listen 8089, ->
    console.log 'Application listen on port ' , PORT