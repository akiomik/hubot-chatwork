HTTPS          = require 'https'
{EventEmitter} = require 'events'

Robot         = (require 'hubot').Robot
Adapter       = (require 'hubot').Adapter
TextMessage   = (require 'hubot').TextMessage

class Chatwork extends Adapter
  # override
  send: (envelope, strings...) ->
    for string in strings
      @bot.Room(envelope.room).Messages().create string, (err, data) =>
        @robot.logger.error "Chatwork send error: #{err}" if err?

  # override
  reply: (envelope, strings...) ->
    @send envelope, strings.map((str) ->
      "[To:#{envelope.user.id}] #{envelope.user.name}さん\n#{str}")...

  # override
  run: ->
    options =
      token: process.env.HUBOT_CHATWORK_TOKEN
      rooms: process.env.HUBOT_CHATWORK_ROOMS
      apiRate: process.env.HUBOT_CHATWORK_API_RATE

    bot = new ChatworkStreaming(options, @robot)

    for roomId in bot.rooms
      bot.Room(roomId).Messages().listen()

    bot.on 'message', (roomId, id, account, body, sendAt, updatedAt) =>
      user = @robot.brain.userForId account.account_id,
        name: account.name
        avatarImageUrl: account.avatar_image_url
        room: roomId
      @receive new TextMessage user, body, id

    @bot = bot

    @emit 'connected'

exports.use = (robot) ->
  new Chatwork robot

class ChatworkStreaming extends EventEmitter
  constructor: (options, @robot) ->
    unless options.token? and options.rooms? and options.apiRate?
      @robot.logger.error \
        'Not enough parameters provided. I need a token, rooms and API rate'
      process.exit 1

    @token = options.token
    @rooms = options.rooms.split ','
    @host = 'api.chatwork.com'
    @rate = parseInt options.apiRate, 10

    unless options.apiRate > 0
      @robot.logger.error 'API rate must be greater then 0'
      process.exit 1

  Me: (callback) =>
    @get "/me", "", callback

  My: =>
    status: (callback) =>
      @get "/my/status", "", callback

    tasks: (options, callback) =>
      body = """
         assigned_by_account_id=#{options.assignedBy}
        &status=#{options.status}
      """
      @get "/my/tasks", body, callback

  Contacts: (callback) =>
    @get "/contacts", "", callback

  Rooms: =>
    show: (callback) =>
      @get "/rooms", "", callback

    # TODO: support optional params
    create: (name, adminIds, options, callback) =>
      body = """
         description=#{options.desc}
        &icon_preset=#{options.icon}
        &members_admin_ids=#{adminIds.join ','}
        &members_member_ids=#{options.memberIds.join ','}
        &members_readonly_ids=#{options.roIds.join ','}
        &name=#{name}
      """
      @post "/rooms", body, callback

  Room: (id) =>
    show: (callback) =>
      @get "/rooms/#{id}", "", callback

    # TODO: support optional params
    update: (options, callback) =>
      body = """
         description=#{options.name}
        &icon_preset=#{options.icon}
        &name=#{options.name}
      """
      @put "/rooms", body, callback

    leave: (callback) =>
      body = "action_type=leave"
      @delete "/rooms/#{id}", body, callback

    delete: (callback) =>
      body = "action_type=delete"
      @delete "/rooms/#{id}", body, callback

    Members: =>
      show: (callback) =>
        @get "/rooms/#{id}/members", "", callback

      # TODO: support optional params
      update: (adminIds, options, callback) =>
        body = """
           members_admin_ids=#{adminIds.join ','}
          &members_member_ids=#{options.memberIds.join ','}
          &members_readonly_ids=#{options.roIds.join ','}
        """
        @put "/rooms/#{id}/members", body, callback

    Messages: =>
      show: (callback) =>
        @get "/rooms/#{id}/messages", "", callback

      create: (text, callback) =>
        body = "body=#{text}"
        @post "/rooms/#{id}/messages", body, callback

      listen: =>
        lastMessage = 0
        setInterval =>
          @show (err, message) =>
            for message in messages
              if lastMessage < message.message_id
                @emit 'message',
                  id,
                  message.message_id,
                  message.account,
                  message.body,
                  message.send_time,
                  message.update_time
                lastMessage = message.message_id
        , 1000 / (@rate / (60 * 60))

    Message: (mid) =>
      show: (callback) =>
        @get "/rooms/#{id}/messages/#{mid}", "", callback

    Tasks: =>
      # TODO: support optional params
      show: (options, callback) =>
        body = """
           account_id=#{options.account}
          &assigned_by_account_id=#{options.assignedBy}
          &status=#{options.status}
        """
        @get "/rooms/#{id}/tasks", body, callback

      # TODO: support optional params
      create: (text, toIds, options, callback) =>
        body = """
           body=#{text}
          &to_ids=#{toIds.join ','}
          &limit=#{options.limit}
        """
        @post "/rooms/#{id}/tasks", body, callback

    Task: (tid) =>
      show: (callback) =>
        @get "/rooms/#{id}/tasks/#{tid}", callback

    Files: =>
      # TODO: support optional params
      show: (options, callback) =>
        body = "account_id=#{options.account}"
        @get "/rooms/#{id}/files", callback

    File: (fid) =>
      # TODO: support optional params
      show: (options, callback) =>
        body = "create_download_url=#{options.createUrl}"
        @get "/rooms/#{id}/files/#{fid}", body, callback

  get: (path, body, callback) ->
    @request "GET", path, body, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  put: (path, body, callback) ->
    @request "PUT", path, body, callback

  delete: (path, body, callback) ->
    @request "DELETE", path, body, callback

  request: (method, path, body, callback) ->
    logger = @robot.logger

    headers =
      "Host"           : @host
      "Content-Type"   : "application/json"
      "X-ChatWorkToken": @token

    options =
      "agent"  : false
      "host"   : @host
      "port"   : 443
      "path"   : "/v1#{path}"
      "method" : method
      "headers": headers

    body = new Buffer(body)
    options.headers["Content-Length"] = body.length

    request = HTTPS.request options, (response) ->
      data = ""

      response.on "data", (chunk) ->
        data += chunk

      response.on "end", ->
        if response.statusCode >= 400
          switch response.statusCode
            when 401
              throw new Error "Invalid access token provided"
            else
              logger.error "Chatwork HTTPS status code: #{response.statusCode}"
              logger.error "Chatwork HTTPS response data: #{data}"

        if callback
          json = try JSON.parse data catch e then data or {}
          callback null, json

      response.on "error", (err) ->
        logger.error "Chatwork HTTPS response error: #{err}"
        callback err, { }

    if method is "POST" || method is "PUT"
      request.end(body, 'binary')
    else
      request.end()

    request.on "error", (err) ->
      logger.error "Chatwork request error: #{err}"

