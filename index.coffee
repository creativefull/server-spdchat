express = require('express')
app = express()
socket_message = require('./socket_message')
server = require('http').Server(app)
io = require('socket.io').listen server
MongoClient = require('mongodb').MongoClient
confDB = require('./database.json')

PORT = process.env.NODE_PORT || 8089

MongoClient.connect "mongodb://" + confDB.host + ":" + confDB.port + "/" + confDB.database, (err, db) ->
    app.get '/', (req,res) ->
        res.sendFile __dirname + '/index.html'

    # SOCKET STREAM
    socket_message io, db
    server.listen 8089, '::', ->
        console.log 'Application listen on port ' , PORT