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
                    socket.emit 'login', {status : 200, msg : 'Login Successfull'}
                else
                    socket.emit 'login', {status : 403, msg : 'Username / Password Not Valid'}

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
                io.emit 'directMsg', {status : 200, data : msg}
        # Get Direct Message
        socket.on 'getDirectMsg', (data) ->
            condition = {
                author : {
                    $in : [data.user]
                }
            }
            console.log condition
            MsgModel.find condition
                .toArray (err, results) ->
                    if (err)
                        throw err
                    socket.emit 'getDirectMsg', results

module.exports = Socket;