# Use if the user name of jira and slack is different
# "jiraName": "slackName"

# map = "hhasegawa": "hhasegawa"

module.exports = (robot) ->
  sendDM = (userName, message, options) ->
    # userName は slack のユーザー名（@hoge の場合は "hoge"）
    # slack の userID を取得
    client = robot.adapter.client
    userId = client.rtm.dataStore.getUserByName(userName)?.id
    return unless userId?

    client.web.chat.postMessage(userId, message, options)
  convertHandleName = (name) ->
    # map[name] || name # コンバートする必要があったらONに
    name
  extractHandleName = (body) ->
    temp = body.match(/\[~.+?\]/g)
    unless temp is null
      name = []
      for i in temp
        name.push("#{i}".replace(/\[|\]|~/g, ""))
      return name
  robot.router.post '/hubot/jira-comment-dm', (req, res) ->
    body = req.body
    if body.webhookEvent == 'comment_created'
      issue = "#{body.issue.key} #{body.issue.fields.summary}"
      url = "#{process.env.HUBOT_JIRA_URL}/browse/#{body.issue.key}"
      author = body.comment.author.name
      handleNameList = extractHandleName(body.comment.body)
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
