Socket = (io, db) ->
    shortid = require('shortid')
    UserModel = db.collection 'users'
    MsgModel = db.collection 'msg'
    BroadModel = db.collection 'broadcast'
    BroadMsgModel = db.collection 'broadMsg'
    LastMsg = db.collection 'lastMsg'
    LastBroad = db.collection 'lastBroad'

    io.on 'connection', (socket) ->
        console.log 'new client connected', socket.id
        socket.emit 'connected', socket.id
        socket.on 'rescue', (rescue_id) ->
            socket.join rescue_id, () ->
                io.to rescue_id
                    .emit 'rescue', 'Joined Group ' + rescue_id
        socket.on 'leftGroup', (group_id) ->
            socket.leave group_id

        socket.on 'msgGroup', (data) ->
            io.to data.group
                .emit 'msgGroup', data.msg
        
        # Create New User
        socket.on 'register', (data) ->
            UserModel.findOne {_id : data.username}, (err, user) ->
                if err
                    throw err
                if user
                    socket.emit 'register', {status : 401, msg : 'User already exists'}
                else
                    UserModel.insert {
                        _id : data.username,
                        first_name : data.first_name,
                        last_name : data.last_name,
                        chat : [],
                        name : data.name,
                        email : data.email,
                        password : data.password,
                        alamat : data.alamat
                    }, (err, result) ->
                        if err
                            throw err;
                        socket.emit 'register', {status : 200, msg : 'Register Successfull', device_id : socket.id}

        # Login User
        socket.on 'login', (data) ->
            UserModel.findOne {_id : data.username, password : data.password}, (err, user) ->
                if err
                    throw err
                if user
                    socket.emit 'login', {status : 200, msg : 'Login Successfull' , data : user
                    }
                else
                    socket.emit 'login', {status : 403, msg : 'Username / Password Not Valid'}

        # Get List Chat
        socket.on 'listChat', (data) ->
            query1 = {
                author : {
                    $in : [data._id]
                }
            }
            # console.log query1
            LastMsg.find query1
                .sort {time : -1}
                .toArray (err, results) ->
                    if (err)
                        throw err
                    if results != null
                        results.forEach (d) ->
                            d.message = d.msg;
                            d.name = if d.sender == data._id then d.receiver else d.sender;
                        io.emit 'listChat', {author : data._id , data : results}


        # Send Direct Message
        socket.on 'directMsg', (data) ->
            msg = {
                receiver : data.receiver,
                sender : data.sender,
                author : [data.receiver, data.sender],
                msg : data.msg,
                time : new Date()
            }
            MsgModel.insert msg, (err, results) ->
                if err
                    throw err
                query1 = {
                    _id : data.sender
                }
                lastm = {
                    author : [data.receiver, data.sender],
                    msg : data.msg,
                    sender : data.sender,
                    receiver : data.receiver,
                    time : new Date()
                }
                queryLastMsg = {
                    $or : [{
                        author : [data.receiver, data.sender]
                    }, {
                        author : [data.sender, data.receiver]
                    }]
                }
                LastMsg.findOne queryLastMsg, (err, result) ->
                    if (result)
                        LastMsg.update queryLastMsg, {$set : {msg : data.msg, sender : data.sender, receiver : data.receiver, time : new Date()}}, ->
                            io.emit 'directMsg', {status : 200, data : msg}
                    else
                        LastMsg.insert lastm, (err, result) ->
                            io.emit 'directMsg', {status : 200, data : msg}
        # Get Direct Message
        socket.on 'getDirectMsg', (data) ->
            condition = {
                $or : [{
                    sender : data.sender,
                    receiver : data.receiver
                },{
                    sender : data.receiver,
                    receiver : data.sender
                }]
            }
            MsgModel.find condition
                .sort({ time : -1 })
                .toArray (err, results) ->
                    if (err)
                        throw err
                    io.emit 'getDirectMsg', {sender : data.sender, receiver : data.receiver , data : results}

        # Get List Contact
        socket.on 'listContact', (data) ->
            query = {
                _id : {
                    $ne : data._id
                }
            }
            UserModel.find query
                .toArray (err, results) ->
                    if (err)
                        throw err
                    io.emit 'listContact', {author : data._id, data : results}
        
        # Get List Chat Broadcast
        socket.on 'listBroad', (data) ->
            query = {
                author : data._id
            }
            console.log(query)
            BroadModel.find query
                .sort({time : -1})
                .toArray (err, results) ->
                    if (err)
                        throw err
                    io.emit 'listBroad', {author : data._id , data : results}

        # create broadcast
        socket.on 'createBroadcast', (data) ->
            id = shortid.generate()
            query = {
                _id : id,
                author : data.author,
                receiver : data.receiver,
                type : data.type,
                time : new Date()
            }
            BroadModel.insert query, (err, rows) ->
                if err
                    throw err
                # console.log data
                io.emit 'new rescue', query
                io.emit 'createBroadcast', {status : 200 , _id : id}

        # Get Broadcast Message
        socket.on 'getBroadMsg', (data) ->
            query = {
                id : data.id,
                sender : data._id
            }
            BroadMsgModel.find query
                .sort({time : -1})
                .toArray (err, results) ->
                    if (err)
                        throw err
                    console.log data
                    io.emit 'getBroadMsg', {sender : data._id , _id : data.id , data : results}

        # Send Broadcast Messages
        socket.on 'broadMsg', (data) ->
            console.log data
            query1 = {
                id : data._id,
                sender : data.sender,
                msg : data.msg,
                receiver : data.receiver,
                time : new Date()
            }
            BroadModel.update {_id : data._id}, { $set : { messages : data.msg}}, ->
                BroadMsgModel.insert query1, (err , docs) ->
                    arr_msg = []
                    for i in data.receiver by -1
                        msg = {
                            receiver : i,
                            sender : data.sender,
                            author : [i, data.sender],
                            msg : data.msg,
                            time : new Date()
                        }
                        console.log msg
                        io.emit 'directMsg', {status : 200 , data : msg}
                        MsgModel.insert msg, (err, results) ->

        # On Edit Profile
        socket.on 'editProfile', (data) ->
            id = data._id
            delete data._id
            UserModel.update {_id : id}, {$set : data}, (err, users) ->
                # console.error err, users
                data._id = id
                socket.emit 'editProfile', {status: 200, data : data}
module.exports = Socket;