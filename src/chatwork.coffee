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

    unless @rate > 0
      @robot.logger.error 'API rate must be greater then 0'
      process.exit 1

  Me: (callback) =>
    @get "/me", "", callback

  My: =>
    status: (callback) =>
      @get "/my/status", "", callback

    tasks: (opts, callback) =>
      params = []
      params.push "assigned_by_account_id=#{opts.assignedBy}" if opts.assignedBy?
      params.push "status=#{opts.status}" if opts.status?
      body = params.join '&'
      @get "/my/tasks", body, callback

  Contacts: (callback) =>
    @get "/contacts", "", callback

  Rooms: =>
    show: (callback) =>
      @get "/rooms", "", callback

    create: (name, adminIds, opts, callback) =>
      params = []
      params.push "name=#{name}"
      params.push "members_admin_ids=#{adminIds.join ','}"
      params.push "description=#{opts.desc}" if opts.desc?
      params.push "icon_preset=#{opts.icon}" if opts.icon?
      params.push "members_member_ids=#{opts.memberIds.join ','}" if opts.memberIds?
      params.push "members_readonly_ids=#{opts.roIds.join ','}" if opts.roIds?
      body = params.join '&'
      @post "/rooms", body, callback

  Room: (id) =>
    baseUrl = "/rooms/#{id}"

    show: (callback) =>
      @get "#{baseUrl}", "", callback

    # TODO: support optional params
    update: (options, callback) =>
      body = "description=#{options.desc}" \
        + "&icon_preset=#{options.icon}" \
        + "&name=#{options.name}"
      @put "#{baseUrl}", body, callback

    leave: (callback) =>
      body = "action_type=leave"
      @delete "#{baseUrl}", body, callback

    delete: (callback) =>
      body = "action_type=delete"
      @delete "#{baseUrl}", body, callback

    Members: =>
      show: (callback) =>
        @get "#{baseUrl}/members", "", callback

      # TODO: support optional params
      update: (adminIds, options, callback) =>
        body = "members_admin_ids=#{adminIds.join ','}" \
          + "&members_member_ids=#{options.memberIds.join ','}" \
          + "&members_readonly_ids=#{options.roIds.join ','}"
        @put "#{baseUrl}/members", body, callback

    Messages: =>
      show: (callback) =>
        @get "#{baseUrl}/messages", "", callback

      create: (text, callback) =>
        body = "body=#{text}"
        @post "#{baseUrl}/messages", body, callback

      listen: =>
        lastMessage = 0
        setInterval =>
          @Room(id).Messages().show (err, messages) =>
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
        @get "#{baseUrl}/messages/#{mid}", "", callback

    Tasks: =>
      # TODO: support optional params
      show: (options, callback) =>
        body = "account_id=#{options.account}" \
          + "&assigned_by_account_id=#{options.assignedBy}" \
          + "&status=#{options.status}"
        @get "#{baseUrl}/tasks", body, callback

      # TODO: support optional params
      create: (text, toIds, options, callback) =>
        body = "body=#{text}" \
          + "&to_ids=#{toIds.join ','}" \
          + "&limit=#{options.limit}"
        @post "#{baseUrl}/tasks", body, callback

    Task: (tid) =>
      show: (callback) =>
        @get "#{baseUrl}/tasks/#{tid}", "", callback

    Files: =>
      # TODO: support optional params
      show: (options, callback) =>
        body = "account_id=#{options.account}"
        @get "#{baseUrl}/files", body, callback

    File: (fid) =>
      # TODO: support optional params
      show: (options, callback) =>
        body = "create_download_url=#{options.createUrl}"
        @get "#{baseUrl}/files/#{fid}", body, callback

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
      "X-ChatWorkToken": @token

    options =
      "agent"  : false
      "host"   : @host
      "port"   : 443
      "path"   : "/v1#{path}"
      "method" : method
      "headers": headers

    body = new Buffer body
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
        callback err, {}

    request.end body, 'binary'

    request.on "error", (err) ->
      logger.error "Chatwork request error: #{err}"

