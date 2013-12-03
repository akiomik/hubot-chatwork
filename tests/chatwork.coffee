should = (require 'chai').should()
nock = require 'nock'
Chatwork = require '../src/chatwork'

token = 'deadbeef'
roomId = '10'
apiRate = '1'
process.env.HUBOT_CHATWORK_TOKEN = token
process.env.HUBOT_CHATWORK_ROOMS = roomId
process.env.HUBOT_CHATWORK_API_RATE = apiRate

class LoggerMock
  error: (message) -> new Error message

class RobotMock
  constructor: ->
    @logger = new LoggerMock

robot = new RobotMock

describe 'chatwork streaming', ->
  bot = null
  api = null
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

  before ->
    api =
      (nock 'https://api.chatwork.com')
        .matchHeader('X-ChatWorkToken', token)
        .get("/v1/rooms/#{roomId}/messages")
        .reply(200, messages)
        .post("/v1/rooms/#{roomId}/messages")
        .reply(200, message_id: 123)

    chatwork = Chatwork.use robot
    chatwork.run()
    bot = chatwork.bot

  it 'should equal token', ->
    bot.token.should.equal token

  it 'should equal roomId', ->
    bot.rooms.should.deep.equal [roomId]

  it 'should have host', ->
    bot.should.have.property 'host'

  it 'should equal API rate', ->
    bot.rate.should.equal parseInt apiRate, 10

  it 'should be able to get messages', ->
    bot.Room(roomId).Messages().show (err, data) ->
      data.should.deep.equal messages

  it 'should be able to create a message', ->
    message = 'This is a test message'
    bot.Room(roomId).Messages().create message, (err, data) ->
      data.should.have.property 'message_id'

