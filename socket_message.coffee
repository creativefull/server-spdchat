Socket = (io, db) ->
    shortid = require('shortid')
    UserModel = db.collection 'users'
    MsgModel = db.collection 'msg'
    BroadModel = db.collection 'broadcast'
    BroadMsgModel = db.collection 'broadMsg'

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
                    }, (err, result) ->
                        if err
                            throw err;
                        socket.emit 'register', {status : 200, msg : 'Register Successfull', device_id : socket.id}

        # Login User
        socket.on 'login', (data) ->
            console.log data
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
                _id : data._id
            }
            UserModel.findOne query1, (err, results) ->
                if (err)
                    throw err
                if (results != null)
                    query2 = {
                        _id : {
                            $in : if results.chat then results.chat else []
                        }
                    }
                    UserModel.find query2
                        .toArray (err, hasil) ->
                            if (err)
                                throw err
                            io.emit 'listChat', {author : data._id , data : hasil}
                else 
                    io.emit 'listChat', []


        # Send Direct Message
        socket.on 'directMsg', (data) -> 
            console.log data
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
                UserModel.update {_id : data.receiver}, { $set : { messages : data.msg}}, ->
                    UserModel.findOne {_id : data.sender}, (err, rowCek) ->
                        if (rowCek != null)
                            cek = rowCek.chat.indexOf(data.receiver)
                            if (cek == -1)
                                UserModel.update query1, { $push : { chat : data.receiver} }, (err, rows) ->
                                    io.emit 'directMsg', {status : 200, data : msg}
                            else
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
                time : new Date()
            }
            BroadModel.insert query, (err, rows) ->
                if err
                    throw err
                io.emit 'createBroadcast', {status : 200 , _id : id}

        # Send Broadcst Messages
        socket.on 'broadMsg', (data) ->
            console.log data
            query1 = {
                id : data._id,
                sender : data.sender,
                msg : data.msg,
                receiver : data.receiver
            }
            BroadMsgModel.insert query1, (err , docs) ->
                arr_msg = []
                for i in data.receiver by -1
                    arr_msg.push({
                        receiver : i,
                        sender : data.sender,
                        author : [i, data.sender],
                        msg : data.msg,
                        time : new Date()
                    })
                console.log arr_msg
module.exports = Socket;