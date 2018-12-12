# Description:
#   朝会お知らせ
#
# Configuration:
#   ASAKAI_ROOM_NAME
#
# Dependencies:
#   "cron": "^1.3.0"
#   "moment": "^2.20.1"
#
# Commands:
#   hubot members ls - メンバーを表示
#   hubot members add <slack_account> <github_account> <atlassian_account> <dept> - メンバーを追加
#   hubot members rm/-rf - メンバーをすべて削除
#   hubot members rm <name> - メンバーを削除
#   hubot members gacha - メンバーガチャ
#   hubot members gacha 3 - メンバー3連ガチャ
#   hubot members dept-gacha <dept_name> 3 - チームメンバー3連ガチャ
#   hubot gacha <item1 item2 item3> - ガチャ

moment = require 'moment'
{CronJob} = require 'cron'
moment.locale('ja')

# Sorry
Array.prototype.random = (number = 1)->
  dupped = @concat()
  result = []
  [0...number].forEach ->
    index = Math.floor(Math.random() * dupped.length)
    bingo = dupped.splice(index, 1)[0]
    result.push bingo
  if number is 1
    result[0]
  else
    result

BRAIN_KEYS_MEMBERS = 'members'

module.exports = (robot) ->

  robot.respond /members ls/i, (res) ->
    members = robot.brain.get(BRAIN_KEYS_MEMBERS)
    res.send JSON.stringify members

  robot.respond /members add (\S+)\s(\S+)\s(\S+)\s(\S+)/i, (res) ->
    name = res.match[1].trim()
    github = res.match[2].trim()
    atlassian = res.match[3].trim()
    dept = res.match[4].trim()
    members = robot.brain.get(BRAIN_KEYS_MEMBERS) or []
    members.push {name, github, atlassian, dept}
    robot.brain.set(BRAIN_KEYS_MEMBERS, members)
    res.send "added #{name}"
    res.send JSON.stringify members

  robot.respond /members rm\/-rf/i, (res) ->
    robot.brain.set(BRAIN_KEYS_MEMBERS, [])
    res.send "removed all members!"

  robot.respond /members rm (\S+)/i, (res) ->
    name = res.match[1].trim()
    members = robot.brain.get(BRAIN_KEYS_MEMBERS) or []
    newMembers = members.filter (member)-> member.name isnt name
    robot.brain.set(BRAIN_KEYS_MEMBERS, newMembers)
    res.send "removed #{name}"
    res.send JSON.stringify newMembers

  robot.respond /members dept-gacha (\S+)\s*(\d*)$/i, (res) ->
    members = robot.brain.get(BRAIN_KEYS_MEMBERS) or []
    dept = res.match[1].trim()
    count = Number(res.match[2] || 1)

    deptMembers = members.filter (m) -> m.dept is dept

    if count in [1, NaN]
      res.send "@#{deptMembers.random()?.name}"
    else
      res.send deptMembers.random(count).map(({name} = {name: null})-> "@#{name}" ).join(' -> ')

  robot.respond /members gacha(\s*)(\d*)$/i, (res) ->
    members = robot.brain.get(BRAIN_KEYS_MEMBERS) or []
    count = Number(res.match[2] || 1)
    if count in [1, NaN]
      res.send "@#{members.random()?.name}"
    else
      res.send members.random(count).map(({name} = {name: null})-> "@#{name}" ).join(' -> ')

  robot.respond /gacha (.+)$/i, (res) ->
    items = res.match[1].split(/\s+/)
    res.send items.random()
