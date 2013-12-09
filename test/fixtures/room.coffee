exports.get =
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

exports.put = room_id: 1234

exports.delete = {}

exports.members = require './room/members'

exports.messages = require './room/messages'

exports.message = require './room/message'

exports.tasks = require './room/tasks'

exports.task = require './room/task'

exports.files = require './room/files'

exports.file = require './room/file'

