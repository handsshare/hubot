# Use if the user name of jira and slack is different
# "jiraName": "slackName"

BRAIN_KEYS_MEMBERS = 'members'

module.exports = (robot) ->
  sendDM = (userName, message, body) ->
    # userName は slack のユーザー名（@hoge の場合は "hoge"）
    # slack の userID を取得
    client = robot.adapter.client
    userId = client.rtm.dataStore.getUserByName(userName)?.id
    return unless userId?

    issue = "#{body.issue.key} #{body.issue.fields.summary}"
    url = "#{process.env.HUBOT_JIRA_URL}/browse/#{body.issue.key}"
    author = body.user.displayName
    attachments = [
      {
        fallback: "[<#{url}|#{issue}>] assigned by @#{author}",
        color: 'good',
        pretext: "[<#{url}|#{issue}>] assigned by @#{author}"
        title: issue,
        title_link: url,
        fields: [
          {
            title: "",
            value: "#{body.issue.fields.description}",
            short: false
          }
        ],
        footer: author,
        ts: new Date / 1000 | 0
      }
    ]
    options = { as_user: true, link_names: 1, attachments: attachments }
    client.web.chat.postMessage(userId, message, options)

  convertHandleName = (atlassianName) ->
    members = robot.brain.get(BRAIN_KEYS_MEMBERS) or []
    member = members.find ({atlassian})-> atlassian is atlassianName
    member?.name or atlassianName

  robot.router.post '/hubot/jira-assign-dm', (req, res) ->
    body = req.body

    # アサインされている人がいて、Issueの作成時か、更新時の場合はアサイン変更であった場合にDM送信する
    return res.send 'OK' unless body.issue.fields.assignee?
    return res.send 'OK' if body.webhookEvent != 'jira:issue_created' && body.changelog.items[0].field != 'assignee'

    # assgineeから名前の属性が消えてしまったため、ユーザーネームを取得しに行く
    request = require 'request'
    # jira basic authでapiを使っている。
    # info: https://ja.confluence.atlassian.com/cloud/api-tokens-938839638.html
    # ↑で発行したtokenと発行した際のユーザーメールアドレスが必要
    request.get {
      url: body.issue.fields.assignee.self,
      json: true,
      auth: { user: process.env.HUBOT_JIRA_USER, pass: process.env.HUBOT_JIRA_TOKEN }
      }, (error, responce, another_body) ->
      if error or responce.statusCode != 200
        console.log error
        return res.send('ユーザーネームの取得に失敗しました')
      sendDM(convertHandleName(another_body.name), 'イシューにアサインされました。確認しましょう！', body)

    res.send 'OK'


