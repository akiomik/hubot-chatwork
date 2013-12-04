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

api = (nock 'https://api.chatwork.com').matchHeader 'X-ChatWorkToken', token

describe 'chatwork', ->
  chatwork = null

  beforeEach ->
    chatwork = Chatwork.use robot
    nock.cleanAll()

  it 'should be able to run', (done) ->
    api.get("/v1/rooms/#{roomId}/messages").reply 200, (uri, body) -> done()
    chatwork.run()

  it 'should be able to send message', (done) ->
    api.post("/v1/rooms/#{roomId}/messages").reply 200, (uri, body) -> done()

    envelope = room: roomId
    message = "This is a test message"
    chatwork.run()
    chatwork.send envelope, message

  it 'should be able to reply message', (done) ->
    api.post("/v1/rooms/#{roomId}/messages").reply 200, (uri, body) -> done()

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

  describe 'Me', ->
    beforeEach ->
      nock.cleanAll()

    info =
      account_id: 123
      room_id: 322
      name: 'John Smith'
      chatwork_id: 'tarochatworkid'
      organization_id: 101
      organization_name: 'Hello Company'
      department: 'Marketing'
      title: 'CMO'
      url: 'http://mycompany.com'
      introduction: 'Self Introduction'
      mail: 'taro@example.com'
      tel_organization: 'XXX-XXXX-XXXX'
      tel_extension: 'YYY-YYYY-YYYY'
      tel_mobile: 'ZZZ-ZZZZ-ZZZZ'
      skype: 'myskype_id'
      facebook: 'myfacebook_id'
      twitter: 'mytwitter_id'
      avatar_image_url: 'https://example.com/abc.png'

    it 'should be able to get own informations', (done) ->
      api.get('/v1/me').reply 200, info
      bot.Me (err, data) ->
        data.should.deep.equal info
        done()

  describe 'My', ->
    beforeEach ->
      nock.cleanAll()

    it 'should be able to get my status', (done) ->
      status =
        unread_room_num: 2
        mention_room_num: 1
        mytask_room_num: 3
        unread_num: 12
        mention_num: 1
        mytask_num: 8

      api.get('/v1/my/status').reply 200, status
      bot.My().status (err, data) ->
        data.should.deep.equal status
        done()

    it 'should be able to get my tasks', (done) ->
      tasks = [
        task_id: 3
        room:
          room_id: 5
          name: "Group Chat Name"
          icon_path: "https://example.com/ico_group.png"
        assigned_by_account:
          account_id: 456
          name: "Anna"
          avatar_image_url: "https://example.com/def.png"
        message_id: 13
        body: "buy milk"
        limit_time: 1384354799
        status: "open"
      ]

      opts =
        assignedBy: '78'
        status: 'done'

      api.get('/v1/my/tasks').reply 200, (url, body) ->
        params = body.split '&'
        p0 = params[0].split '='
        p1 = params[1].split '='
        if p0[0] is 'status'
          p0[1].should.be.equal opts.status
          p1[1].should.be.equal opts.assignedBy
        else
          p0[1].should.be.equal opts.assignedBy
          p1[1].should.be.equal opts.status
        tasks

      bot.My().tasks opts, (err, data) ->
        data.should.be.deep.equal tasks
        done()

  describe 'Contacts', ->
    beforeEach ->
      nock.cleanAll()

    contacts = [
      account_id: 123
      room_id: 322
      name: "John Smith"
      chatwork_id: "tarochatworkid"
      organization_id: 101
      organization_name: "Hello Company"
      department: "Marketing"
      avatar_image_url: "https://example.com/abc.png"
    ]

    it 'should be able to get contacts', (done) ->
      api.get('/v1/contacts').reply 200, contacts
      bot.Contacts (err, data) ->
        data.should.deep.equal contacts
        done()

  describe 'Rooms', ->
    rooms = [
      room_id: 123
      name: "Group Chat Name"
      type: "group"
      role: "admin"
      sticky: false
      unread_num: 10
      mention_num: 1
      mytask_num: 0
      message_num: 122
      file_num: 10
      task_num: 17
      icon_path: "https://example.com/ico_group.png"
      last_update_time: 1298905200
    ]

    beforeEach ->
      nock.cleanAll()

    it 'should be able to show rooms', (done) ->
      api.get('/v1/rooms').reply 200, rooms
      bot.Rooms().show (err, data) ->
        data.should.deep.equal rooms
        done()

    it 'should be able to create rooms', (done) ->
      res = roomId: 1234
      name = 'Website renewal project'
      adminIds = [123, 542, 1001]
      opts =
        desc: 'group chat description'
        icon: 'meeting'
        memberIds: [21, 344]
        roIds: [15, 103]
      api.post('/v1/rooms').reply 200, (url, body) ->
        params = body.split '&'
        p0 = params[0].split '='
        p1 = params[1].split '='
        p2 = params[2].split '='
        p3 = params[3].split '='
        p4 = params[4].split '='
        p5 = params[5].split '='
        p0[1].should.be.equal opts.desc
        p1[1].should.be.equal opts.icon
        p2[1].should.be.equal adminIds.join ','
        p3[1].should.be.equal opts.memberIds.join ','
        p4[1].should.be.equal opts.roIds.join ','
        p5[1].should.be.equal name
        res

      bot.Rooms().create name, adminIds, opts, (err, data) ->
        data.should.deep.equal res
        done()

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
      api.get("/v1/rooms/#{roomId}/messages").reply 200, messages
      bot.Room(roomId).Messages().show (err, data) ->
        data.should.deep.equal messages
        done()

    it 'should be able to create a message', (done) ->
      res = message_id: 123
      api.post("/v1/rooms/#{roomId}/messages").reply 200, res

      message = 'This is a test message'
      bot.Room(roomId).Messages().create message, (err, data) ->
        data.should.have.property 'message_id'
        done()

    it 'should be able to listen messages', (done) ->
      api.get("/v1/rooms/#{roomId}/messages").reply 200, (url, body) -> done()
      bot.Room(roomId).Messages().listen()

