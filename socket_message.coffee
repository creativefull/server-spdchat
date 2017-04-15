Socket = (io, db) ->
    UserModel = db.collection 'users'
    MsgModel = db.collection 'msg'

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
                        name : data.name,
                        email : data.email,
                        password : data.password
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
                _id : data._id
            }
            UserModel.findOne query1, (err, results) ->
                    if (err)
                        throw err
                    query2 = {
                        _id : {
                            $in : results.chat
                        }
                    }
                    UserModel.find query2
                        .toArray (err, hasil) ->
                            if (err)
                                throw err
                            io.emit 'listChat', hasil

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
                    io.emit 'getDirectMsg', results

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
                    io.emit 'listContact', results

module.exports = Socket;