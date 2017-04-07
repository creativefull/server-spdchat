express = require('express')
app = express()
socket_message = require('./socket_message')
server = require('http').Server(app)
io = require('socket.io').listen server

PORT = process.env.NODE_PORT || 8089

app.get '/', (req,res) ->
    res.sendFile __dirname + '/index.html'

# SOCKET STREAM
socket_message io, null
server.listen 8089, ->
    console.log 'Application listen on port ' , PORT