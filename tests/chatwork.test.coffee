should = (require 'chai').should()
nock = require 'nock'
Chatwork = require '../src/chatwork'

token = 'deadbeef'
roomId = '10'
apiRate = '3600'
process.env.HUBOT_CHATWORK_TOKEN = token
process.env.HUBOT_CHATWORK_ROOMS = roomId
process.env.HUBOT_CHATWORK_API_RATE = apiRate

class LoggerMock
  error: (message) -> new Error message

class RobotMock
  constructor: ->
    @logger = new LoggerMock

robot = new RobotMock

api = (nock 'https://api.chatwork.com')
  .matchHeader 'X-ChatWorkToken', token

describe 'chatwork', ->
  chatwork = null

  beforeEach ->
    chatwork = Chatwork.use robot
    nock.cleanAll()

  it 'should be able to run', (done) ->
    api.get("/v1/rooms/#{roomId}/messages")
      .reply 200, (uri, body) ->
        done()

    chatwork.run()

  it 'should be able to send message', (done) ->
    api.post("/v1/rooms/#{roomId}/messages")
      .reply 200, (uri, body) ->
        done()

    envelope = room: roomId
    message = "This is a test message"
    chatwork.run()
    chatwork.send envelope, message

  it 'should be able to reply message', (done) ->
    api.post("/v1/rooms/#{roomId}/messages")
      .reply 200, (uri, body) ->
        done()

    envelope =
      room: roomId
      user:
        id: 123
        name: "Bob"
    message = "This is a test message"
    chatwork.run()
    chatwork.reply envelope, message

describe 'chatwork streaming', ->
  bot = null

  beforeEach ->
    chatwork = Chatwork.use robot
    chatwork.run()
    bot = chatwork.bot

  it 'should have configs from environment variables', ->
    bot.token.should.equal token
    bot.rooms.should.deep.equal [roomId]
    bot.rate.should.equal parseInt apiRate, 10

  it 'should have host', ->
    bot.should.have.property 'host'

  describe 'Messages', ->
    messages =
      [
        message_id: 5
        account:
          account_id: 123
          name: "Bob"
          avatar_image_url: "https://example.com/ico_avatar.png"
        body: "Hello Chatwork!"
        send_time: 1384242850
        update_time: 0
      ]

    beforeEach ->
      nock.cleanAll()

    it 'should be able to get messages', (done) ->
      api.get("/v1/rooms/#{roomId}/messages")
        .reply(200, messages)

      bot.Room(roomId).Messages().show (err, data) ->
        data.should.deep.equal messages
        done()

    it 'should be able to create a message', (done) ->
      api.post("/v1/rooms/#{roomId}/messages")
        .reply(200, message_id: 123)

      message = 'This is a test message'
      bot.Room(roomId).Messages().create message, (err, data) ->
        data.should.have.property 'message_id'
        done()

    it 'should be able to listen messages', (done) ->
      api.get("/v1/rooms/#{roomId}/messages")
        .reply 200, (url, body) ->
          done()

      bot.Room(roomId).Messages().listen()

