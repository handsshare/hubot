# Use if the user name of jira and slack is different
# "jiraName": "slackName"
BRAIN_KEYS_MEMBERS = 'members'
request = require 'request'

module.exports = (robot) ->
  sendDM = (userName, message, options) ->
    # userName は slack のユーザー名（@hoge の場合は "hoge"）
    # slack の userID を取得
    client = robot.adapter.client
    userId = client.rtm.dataStore.getUserByName(userName)?.id
    return unless userId?

    client.web.chat.postMessage(userId, message, options)

  convertHandleName = (atlassianName) ->
    members = robot.brain.get(BRAIN_KEYS_MEMBERS) or []
    member = members.find ({atlassian})-> atlassian is atlassianName
    member?.name or atlassianName

  extractHandleName = (body) ->
    new Promise((resolve, reject) ->
      temp = body.match(/\[~accountid:.+?\]/g)
      name = []
      promises = []
      unless temp is null
        for i in temp
          jira_user_id = "#{i}".replace(/\[|\]|~|accountid:/g, "")
          promises.push(
            new Promise((resovle_child, reject_child) ->
              request.get {
                url: "http://handsshare.atlassian.net/rest/api/3/user?accountId=#{jira_user_id}",
                json: true,
                auth: { user: process.env.HUBOT_JIRA_USER, pass: process.env.HUBOT_JIRA_TOKEN }
              }, (error, responce, another_body) ->
                if error or responce.statusCode != 200
                  console.log error
                  reject_child 'JiraIDからのユーザーネームの取得に失敗しました'
                resovle_child another_body.name
            ).then((value) ->
              name.push(value)
            )
          )
      Promise.all(promises).then( () ->
        resolve name
      ))

  robot.router.post '/hubot/jira-comment-dm', (req, res) ->
    body = req.body
    if body.webhookEvent == 'comment_created'
      issue = "#{body.issue.key} #{body.issue.fields.summary}"
      url = "#{process.env.HUBOT_JIRA_URL}/browse/#{body.issue.key}"
      author = body.comment.author.name

      extractHandleName(body.comment.body).then (handleNameList) ->
        unless handleNameList is null
          attachments = [
            {
              fallback: "[<#{url}|#{issue}>] commented by @#{author}",
              color: 'good',
              pretext: "[<#{url}|#{issue}>] commented by @#{author}"
              title: issue,
              title_link: url,
              fields: [
                {
                  title: "",
                  value: "#{body.comment.body}",
                  short: false
                }
              ],
              footer: author,
              ts: new Date / 1000 | 0
            }
          ]
          options = { as_user: true, link_names: 1, attachments: attachments }
          for i in handleNameList
            sendDM(convertHandleName(i), 'あなた宛のコメントがあります。確認しましょう！', options)
        res.send 'OK'
