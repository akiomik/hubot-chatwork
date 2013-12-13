should = (require 'chai').should()
nock = require 'nock'
Chatwork = require '../src/chatwork'
fixtures = require './fixtures'

token = 'deadbeef'
roomId = '10'
apiRate = '3600'
process.env.HUBOT_CHATWORK_TOKEN = token
process.env.HUBOT_CHATWORK_ROOMS = roomId
process.env.HUBOT_CHATWORK_API_RATE = apiRate

class LoggerMock
  error: (message) -> new Error message

class BrainMock
  userForId: (id, options) ->
    id: id
    user: options

class RobotMock
  constructor: ->
    @logger = new LoggerMock
    @brain = new BrainMock

  receive: ->

describe 'Chatwork', ->
  api = null
  robot = null
  chatwork = null

  beforeEach ->
    nock.cleanAll()
    api = (nock 'https://api.chatwork.com')
      .persist()
      .matchHeader('X-ChatWorkToken', token)
      .get("/v1/rooms/#{roomId}/messages")
      .reply 200, fixtures.room.messages.get

    robot = new RobotMock()
    chatwork = Chatwork.use robot

  describe '#run()', ->
    it 'should call api', (done) ->
      nock.cleanAll()
      (nock 'https://api.chatwork.com')
        .persist()
        .matchHeader('X-ChatWorkToken', token)
        .get("/v1/rooms/#{roomId}/messages")
        .reply 200, -> done()
      chatwork.run()

    it 'should call robot.receive on message', (done) ->
      chatwork.robot.receive = (message) -> done()
      chatwork.run()

  describe '#post()', ->
    it 'should send message', (done) ->
      api.post("/v1/rooms/#{roomId}/messages").reply 200, -> done()

      envelope = room: roomId
      message = "This is a test message"
      chatwork.run()
      chatwork.send envelope, message

  describe '#reply()', ->
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
  api = null
  robot = null
  bot = null

  beforeEach ->
    nock.cleanAll()
    api = (nock 'https://api.chatwork.com')
      .persist()
      .matchHeader('X-ChatWorkToken', token)
      .get("/v1/rooms/#{roomId}/messages")
      .reply 200, fixtures.room.messages.get

    robot = new RobotMock()
    chatwork = Chatwork.use robot
    chatwork.run()
    bot = chatwork.bot

  it 'should have configs from environment variables', ->
    bot.token.should.be.equal token
    bot.rooms.should.be.deep.equal [roomId]
    bot.rate.should.be.equal parseInt apiRate, 10

  it 'should have host', ->
    bot.should.have.property 'host'

  describe '#Me()', ->
    it 'should get own informations', (done) ->
      api.get('/v1/me').reply 200, fixtures.me.get
      bot.Me (err, data) ->
        data.should.be.deep.equal fixtures.me.get
        done()

  describe '#My()', ->
    describe '#status', ->
      it 'should get my status', (done) ->
        api.get('/v1/my/status').reply 200, fixtures.my.status.get
        bot.My().status (err, data) ->
          data.should.be.deep.equal fixtures.my.status.get
          done()

    describe '#tasks()', ->
      it 'should get my tasks', (done) ->
        api.get('/v1/my/tasks').reply 200, fixtures.my.tasks.get
        bot.My().tasks {}, (err, data) ->
          data.should.be.deep.equal fixtures.my.tasks.get
          done()

      it 'should get my tasks when no opts', (done) ->
        api.get('/v1/my/tasks').reply 200, (url, body) ->
          body.should.be.equal ""
          done()
        bot.My().tasks {}, null

      it 'should get my tasks when full opts', (done) ->
        opts =
          assignedBy: 78
          status: 'done'
        api.get('/v1/my/tasks').reply 200, (url, body) ->
          params = Helper.parseBody body
          params.should.be.deep.equal
            assigned_by_account_id: "#{opts.assignedBy}"
            status: opts.status
          done()
        bot.My().tasks opts, null

  describe '#Contacts()', ->
    it 'should get contacts', (done) ->
      api.get('/v1/contacts').reply 200, fixtures.contacts.get
      bot.Contacts (err, data) ->
        data.should.be.deep.equal fixtures.contacts.get
        done()

  describe '#Rooms()', ->
    describe '#show()', ->
      it 'should show rooms', (done) ->
        api.get('/v1/rooms').reply 200, fixtures.rooms.get
        bot.Rooms().show (err, data) ->
          data.should.be.deep.equal fixtures.rooms.get
          done()

    describe '#create()', ->
      it 'should create a room', (done) ->
        name = 'Website renewal project'
        adminIds = [123, 542, 1001]
        api.post('/v1/rooms').reply 200, fixtures.rooms.post
        bot.Rooms().create name, adminIds, {}, (err, data) ->
          data.should.be.deep.equal fixtures.rooms.post
          done()

      it 'should create a room when no opts', (done) ->
        name = 'Website renewal project'
        adminIds = [123, 542, 1001]
        api.post('/v1/rooms').reply 200, (url, body) ->
          body.should.be.equal "name=#{name}" \
            + "&members_admin_ids=#{adminIds.join ','}"
          done()
        bot.Rooms().create name, adminIds, {}, null

      it 'should create a room when full opts', (done) ->
        name = 'Website renewal project'
        adminIds = [123, 542, 1001]
        opts =
          desc: 'group chat description'
          icon: 'meeting'
          memberIds: [21, 344]
          roIds: [15, 103]
        api.post('/v1/rooms').reply 200, (url, body) ->
          params = Helper.parseBody body
          params.should.be.deep.equal
            description:  opts.desc
            icon_preset: opts.icon
            members_admin_ids: adminIds.join ','
            members_member_ids: opts.memberIds.join ','
            members_readonly_ids: opts.roIds.join ','
            name: name
          done()
        bot.Rooms().create name, adminIds, opts, null

  describe '#Room()', ->
    room = null
    baseUrl = "/v1/rooms/#{roomId}"

    before ->
      room = bot.Room(roomId)

    describe '#show()', ->
      it 'should show a room', (done) ->
        api.get(baseUrl).reply 200, fixtures.room.get
        room.show (err, data) ->
          data.should.be.deep.equal fixtures.room.get
          done()

    describe '#update()', ->
      it 'should update a room', (done) ->
        api.put(baseUrl).reply 200, fixtures.room.put
        room.update {}, (err, data) ->
          data.should.be.deep.equal fixtures.room.put
          done()

      it 'should update a room when no opts', (done) ->
        api.put(baseUrl).reply 200, (url, body) ->
          body.should.be.equal ""
          done()
        room.update {}, null

      it 'should update a room when full opts', (done) ->
        opts =
          desc: 'group chat description'
          icon: 'meeting'
          name: 'Website renewal project'

        api.put(baseUrl).reply 200, (url, body) ->
          params = Helper.parseBody body
          params.should.be.deep.equal
            description: opts.desc
            icon_preset: opts.icon
            name: opts.name
          done()
        room.update opts, null

    describe '#leave()', ->
      it 'should leave a room', (done) ->
        api.delete(baseUrl).reply 200, (url, body) ->
          body.should.be.equal "action_type=leave"
          fixtures.room.delete

        room.leave (err, data) ->
          data.should.be.deep.equal fixtures.room.delete
          done()

    describe '#delete()', ->
      it 'should delete a room', (done) ->
        api.delete(baseUrl).reply 200, (url, body) ->
          body.should.be.equal "action_type=delete"
          fixtures.room.delete

        room.delete (err, data) ->
          data.should.be.deep.equal fixtures.room.delete
          done()

    describe 'Members', ->
      describe '#show()', ->
        it 'should show members', (done) ->
          api.get("#{baseUrl}/members").reply 200, fixtures.room.members.get
          room.Members().show (err, data) ->
            data.should.be.deep.equal fixtures.room.members.get
            done()

      describe '#update()', ->
        it 'should update members', (done) ->
          adminIds = [123, 542, 1001]
          api.put("#{baseUrl}/members").reply 200, fixtures.room.members.put
          room.Members().update adminIds, {}, (err, data) ->
            data.should.be.deep.equal fixtures.room.members.put
            done()

        it 'should update members when no opts', (done) ->
          adminIds = [123, 542, 1001]
          api.put("#{baseUrl}/members").reply 200, (url, body) ->
            body.should.be.equal "members_admin_ids=#{adminIds.join ','}"
            done()
          room.Members().update adminIds, {}, null

        it 'should update members when full opts', (done) ->
          adminIds = [123, 542, 1001]
          opts =
            memberIds: [21, 344]
            roIds: [15, 103]

          api.put("#{baseUrl}/members").reply 200, (url, body) ->
            params = Helper.parseBody body
            params.should.be.deep.equal
              members_admin_ids: adminIds.join ','
              members_member_ids: opts.memberIds.join ','
              members_readonly_ids: opts.roIds.join ','
            done()
          room.Members().update adminIds, opts, null

    describe '#Messages()', ->
      describe '#show()', ->
        it 'should get messages', (done) ->
          api.get("#{baseUrl}/messages").reply 200, fixtures.room.messages.get
          room.Messages().show (err, data) ->
            data.should.be.deep.equal fixtures.room.messages.get
            done()

      describe '#create()', ->
        it 'should create a message', (done) ->
          message = 'This is a test message'
          api.post("#{baseUrl}/messages").reply 200, (url, body) ->
            body.should.be.equal "body=#{message}"
            fixtures.room.messages.post

          room.Messages().create message, (err, data) ->
            data.should.be.deep.equal fixtures.room.messages.post
            done()

      describe '#listen()', ->
        it 'should listen messages', ->
          # TODO

    describe '#Message()', ->
      describe '#show()', ->
        it 'should show a message', (done) ->
          messageId = 5
          res = fixtures.room.message.get
          api.get("#{baseUrl}/messages/#{messageId}").reply 200, res
          room.Message(messageId).show (err, data) ->
            data.should.be.deep.equal res
            done()

    describe '#Tasks()', ->
      describe '#show()', ->
        it 'should show tasks', (done) ->
          api.get("#{baseUrl}/tasks").reply 200, fixtures.room.tasks.get
          room.Tasks().show {}, (err, data) ->
            data.should.be.deep.equal fixtures.room.tasks.get
            done()

        it 'should show tasks when no opts', (done) ->
          api.get("#{baseUrl}/tasks").reply 200, (url, body) ->
            body.should.be.equal ""
            done()
          room.Tasks().show {}, null

        it 'should show tasks when full opts', (done) ->
          opts =
            account: '101'
            assignedBy: '78'
            status: "done"

          api.get("#{baseUrl}/tasks").reply 200, (url, body) ->
            params = Helper.parseBody body
            params.should.be.deep.equal
              account_id: opts.account
              assigned_by_account_id: opts.assignedBy
              status: opts.status
            done()
          room.Tasks().show opts, null

      describe '#create()', ->
        it 'should create a task', (done) ->
          text = "Buy milk"
          toIds = [1, 3, 6]
          api.post("#{baseUrl}/tasks").reply 200, fixtures.room.tasks.post
          room.Tasks().create text, toIds, {}, (err, data) ->
            data.should.be.deep.equal fixtures.room.tasks.post
            done()

        it 'should create a task when no opts', (done) ->
          text = "Buy milk"
          toIds = [1, 3, 6]
          api.post("#{baseUrl}/tasks").reply 200, (url, body) ->
            body.should.be.equal "body=#{text}&to_ids=#{toIds.join ','}"
            done()
          room.Tasks().create text, toIds, {}, null

        it 'should create a task when full opts', (done) ->
          text = "Buy milk"
          toIds = [1, 3, 6]
          opts = limit: 1385996399

          api.post("#{baseUrl}/tasks").reply 200, (url, body) ->
            params = Helper.parseBody body
            params.should.be.deep.equal
              body: text
              limit: "#{opts.limit}"
              to_ids: toIds.join ','
            done()
          room.Tasks().create text, toIds, opts, null

    describe '#Task()', ->
      describe '#show()', ->
        it 'should show a task', (done) ->
          taskId = 3
          res = fixtures.room.task.get
          api.get("#{baseUrl}/tasks/#{taskId}").reply 200, res
          room.Task(taskId).show (err, data) ->
            data.should.be.deep.equal res
            done()

    describe '#Files()', ->
      describe '#show()', ->
        it 'should show files', (done) ->
          api.get("#{baseUrl}/files").reply 200, fixtures.room.files.get
          room.Files().show {}, (err, data) ->
            data.should.be.deep.equal fixtures.room.files.get
            done()

        it 'should show files when no opts', (done) ->
          api.get("#{baseUrl}/files").reply 200, (url, body) ->
            body.should.be.equal ""
            done()
          room.Files().show {}, null

        it 'should show files when full opts', (done) ->
          opts = account: 101
          api.get("#{baseUrl}/files").reply 200, (url, body) ->
            body.should.be.equal "account_id=#{opts.account}"
            fixtures.room.files.get
            done()
          room.Files().show opts, null

    describe '#File()', ->
      fileId = 3

      describe '#show()', ->
        it 'should show a file', (done) ->
          res = fixtures.room.file.get
          api.get("#{baseUrl}/files/#{fileId}").reply 200, res
          room.File(fileId).show {}, (err, data) ->
            data.should.be.deep.equal res
            done()

        it 'should show a file when no opts', (done) ->
          api.get("#{baseUrl}/files/#{fileId}").reply 200, (url, body) ->
            body.should.be.equal ""
            done()
          room.File(fileId).show {}, null

        it 'should show a file', (done) ->
          opts = createUrl: true
          api.get("#{baseUrl}/files/#{fileId}").reply 200, (url, body) ->
            body.should.be.equal "create_download_url=#{opts.createUrl}"
            done()
          room.File(fileId).show opts, null

class Helper
  # reqest body to object
  # static
  @parseBody: (body) ->
    obj = {}
    params = body.split '&'
    for param in params
      [key, value] = param.split '='
      obj[key] = value
    obj

