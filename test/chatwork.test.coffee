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

describe 'Chatwork', ->
  chatwork = null

  beforeEach ->
    chatwork = Chatwork.use robot
    nock.cleanAll()

  it 'should run', (done) ->
    api.get("/v1/rooms/#{roomId}/messages").reply 200, -> done()
    chatwork.run()

  it 'should send message', (done) ->
    api.post("/v1/rooms/#{roomId}/messages").reply 200, -> done()

    envelope = room: roomId
    message = "This is a test message"
    chatwork.run()
    chatwork.send envelope, message

  it 'should reply message', (done) ->
    api.post("/v1/rooms/#{roomId}/messages").reply 200, -> done()

    envelope =
      room: roomId
      user:
        id: 123
        name: "Bob"
    message = "This is a test message"
    chatwork.run()
    chatwork.reply envelope, message

describe 'ChatworkStreaming', ->
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

  describe '#Me()', ->
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

    it 'should get own informations', (done) ->
      api.get('/v1/me').reply 200, info
      bot.Me (err, data) ->
        data.should.deep.equal info
        done()

  describe '#My()', ->
    beforeEach ->
      nock.cleanAll()

    it 'should get my status', (done) ->
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

    it 'should get my tasks', (done) ->
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
        assignedBy: 78
        status: 'done'

      api.get('/v1/my/tasks').reply 200, (url, body) ->
        params = body.split '&'
        p0 = params[0].split '='
        p1 = params[1].split '='
        p0[1].should.be.equal "#{opts.assignedBy}"
        p1[1].should.be.equal opts.status
        tasks

      bot.My().tasks opts, (err, data) ->
        data.should.be.deep.equal tasks
        done()

  describe '#Contacts()', ->
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

    it 'should get contacts', (done) ->
      api.get('/v1/contacts').reply 200, contacts
      bot.Contacts (err, data) ->
        data.should.deep.equal contacts
        done()

  describe '#Rooms()', ->
    beforeEach ->
      nock.cleanAll()

    it 'should show rooms', (done) ->
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

      api.get('/v1/rooms').reply 200, rooms
      bot.Rooms().show (err, data) ->
        data.should.deep.equal rooms
        done()

    it 'should create rooms', (done) ->
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

  describe '#Room()', ->
    room = null
    baseUrl = "/v1/rooms/#{roomId}"

    before ->
      room = bot.Room(roomId)

    beforeEach ->
      nock.cleanAll()

    it 'should show a room', (done) ->
      res =
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
        description: "room description text"

      api.get(baseUrl).reply 200, res
      room.show (err, data) ->
        data.should.deep.equal res
        done()

    it 'should update a room', (done) ->
      res = room_id: 1234
      opts =
        desc: 'group chat description'
        icon: 'meeting'
        name: 'Website renewal project'

      api.put(baseUrl).reply 200, (url, body) ->
        params = body.split '&'
        p0 = params[0].split '='
        p1 = params[1].split '='
        p2 = params[2].split '='
        p0[1].should.equal opts.desc
        p1[1].should.equal opts.icon
        p2[1].should.equal opts.name
        res

      room.update opts, (err, data) ->
        data.should.deep.equal res
        done()

    it 'should leave a room', (done) ->
      res = {}
      api.delete(baseUrl).reply 200, (url, body) ->
        body.should.equal "action_type=leave"
        res

      room.leave (err, data) ->
        data.should.deep.equal res
        done()

    it 'should delete a room', (done) ->
      res = {}
      api.delete(baseUrl).reply 200, (url, body) ->
        body.should.equal "action_type=delete"
        res

      room.delete (err, data) ->
        data.should.deep.equal res
        done()

    describe 'Members', ->
      beforeEach ->
        nock.cleanAll()

      it 'should show members', (done) ->
        res = [
          account_id: 123
          role: "member"
          name: "John Smith"
          chatwork_id: "tarochatworkid"
          organization_id: 101
          organization_name: "Hello Company"
          department: "Marketing"
          avatar_image_url: "https://example.com/abc.png"
        ]
        api.get("#{baseUrl}/members").reply 200, res
        room.Members().show (err, data) ->
          data.should.deep.equal res
          done()

      it 'should update members', (done) ->
        adminIds = [123, 542, 1001]
        opts =
          memberIds: [21, 344]
          roIds: [15, 103]
        res =
          admin: [123, 542, 1001]
          member: [10, 103]
          readonly: [6, 11]

        api.put("#{baseUrl}/members").reply 200, (url, body) ->
          params = body.split '&'
          p0 = params[0].split '='
          p1 = params[1].split '='
          p2 = params[2].split '='
          p0[1].should.equal adminIds.join ','
          p1[1].should.equal opts.memberIds.join ','
          p2[1].should.equal opts.roIds.join ','
          res

        room.Members().update adminIds, opts, (err, data) ->
          data.should.deep.equal res
          done()

    describe '#Messages()', ->
      beforeEach ->
        nock.cleanAll()

      it 'should get messages', (done) ->
        res = [
          message_id: 5
          account:
            account_id: 123
            name: "Bob"
            avatar_image_url: "https://example.com/ico_avatar.png"
          body: "Hello Chatwork!"
          send_time: 1384242850
          update_time: 0
        ]

        api.get("#{baseUrl}/messages").reply 200, res
        room.Messages().show (err, data) ->
          data.should.deep.equal res
          done()

      it 'should create a message', (done) ->
        message = 'This is a test message'
        res = message_id: 123

        api.post("#{baseUrl}/messages").reply 200, res
        room.Messages().create message, (err, data) ->
          data.should.have.property 'message_id'
          done()

      it 'should listen messages', (done) ->
        api.get("#{baseUrl}/messages").reply 200, -> done()
        room.Messages().listen()

    describe '#Message()', ->
      beforeEach ->
        nock.cleanAll()

      it 'should show a message', (done) ->
        messageId = 5
        res =
          message_id: 5
          account:
            account_id: 123
            name: "Bob"
            avatar_image_url: "https://example.com/ico_avatar.png"
          body: "Hello Chatwork!"
          send_time: 1384242850
          update_time: 0

        api.get("#{baseUrl}/messages/#{messageId}").reply 200, res
        room.Message(messageId).show (err, data) ->
          data.should.deep.equal res
          done()

    describe '#Tasks()', ->
      beforeEach ->
        nock.cleanAll()

      it 'should show tasks', (done) ->
        opts =
          account: '101'
          assignedBy: '78'
          status: "done"
        res = [
          task_id: 3
          room:
            room_id: 5
            name: "Group Chat Name"
            icon_path: "https://example.com/ico_group.png"
          account:
            account_id: 123
            name: "Bob"
            avatar_image_url: "https://example.com/abc.png"
          assigned_by_account:
            account_id: 456
            name: "Anna"
            avatar_image_url: "https://example.com/def.png"
          message_id: 13
          body: "buy milk"
          limit_time: 1384354799
          status: "open"
        ]

        api.get("#{baseUrl}/tasks").reply 200, (url, body) ->
          params = body.split '&'
          p0 = params[0].split '='
          p1 = params[1].split '='
          p2 = params[2].split '='
          p0[1].should.equal opts.account
          p1[1].should.equal opts.assignedBy
          p2[1].should.equal opts.status
          res

        room.Tasks().show opts, (err, data) ->
          data.should.deep.equal res
          done()

      it 'should create a task', (done) ->
        text = "Buy milk"
        toIds = [1, 3, 6]
        opts = limit: 1385996399
        res = task_ids: [123, 124]

        api.post("#{baseUrl}/tasks").reply 200, (url, body) ->
          params = body.split '&'
          p0 = params[0].split '='
          p1 = params[1].split '='
          p2 = params[2].split '='
          p0[1].should.equal text
          p1[1].should.equal toIds.join ','
          p2[1].should.equal "#{opts.limit}"
          res

        room.Tasks().create text, toIds, opts, (err, data) ->
          data.should.deep.equal res
          done()

    describe '#Task()', ->
      beforeEach ->
        nock.cleanAll()

      it 'should show a task', (done) ->
        taskId = 3
        res =
          task_id: 3
          account:
            account_id: 123
            name: "Bob"
            avatar_image_url: "https://example.com/abc.png"
          assigned_by_account:
            account_id: 456
            name: "Anna"
            avatar_image_url: "https://example.com/def.png"
          message_id: 13
          body: "buy milk"
          limit_time: 1384354799
          status: "open"

        api.get("#{baseUrl}/tasks/#{taskId}").reply 200, res
        room.Task(taskId).show (err, data) ->
          data.should.deep.equal res
          done()

    describe '#Files()', ->
      beforeEach ->
        nock.cleanAll()

      it 'should show files', (done) ->
        opts = account: 101
        res = [
          file_id: 3
          account:
            account_id: 123
            name: "Bob"
            avatar_image_url: "https://example.com/ico_avatar.png"
          message_id: 22
          filename: "README.md"
          filesize: 2232
          upload_time: 1384414750
        ]

        api.get("#{baseUrl}/files").reply 200, (url, body) ->
          p0 = body.split '='
          p0[1].should.equal "#{opts.account}"
          res

        room.Files().show opts, (err, data) ->
          data.should.deep.equal res
          done()

    describe '#File()', ->
      beforeEach ->
        nock.cleanAll()

      it 'should show a file', (done) ->
        fileId = 3
        opts = createUrl: true
        res =
          file_id: 3
          account:
            account_id: 123
            name: "Bob"
            avatar_image_url: "https://example.com/ico_avatar.png"
          message_id: 22
          filename: "README.md"
          filesize: 2232
          upload_time: 1384414750

        api.get("#{baseUrl}/files/#{fileId}").reply 200, (url, body) ->
          p0 = body.split '='
          p0[1].should.equal "#{opts.createUrl}"
          res

        room.File(fileId).show opts, (err, data) ->
          data.should.deep.equal res
          done()

