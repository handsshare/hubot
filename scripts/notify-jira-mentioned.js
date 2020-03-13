const request = require('request');
const BRAIN_KEYS_MEMBERS = 'members';
const JIRA_URL = process.env.HUBOT_JIRA_URL || 'https://jira.example.org';

module.exports = (robot) => {
  // 文字列からJIRAのメンションを抽出して返す
  // @param [String] string eg "[~accountid:hogehogehoge] hello and [~accountid:fugafuga]"
  // @return [Array<String>] eg ["hogehogehoge", "fugafuga"]
  function extractHandleName(string) {
    return string
      .match(/\[~accountid:.+?\]/g)
      .map( raw => raw.replace('[~accountid:', '').replace(']', ''))
  }

  // Slack DM送信
  function sendDM(userName, message, options) {

    const client = robot.adapter.client

    // slack の userID を取得
    const user = client.rtm.dataStore.getUserByName(userName)

    if (!user) {
      robot.logger.error(`${userName}さんがSlack上に存在しません。`)
    }

    client.web.chat.postMessage(user.id, message, options)
  }

  // JiraのコメントのWebHookのbodyから Slack投稿用のオプションを作成する
  function makeSlackOptions(rawJiraBody) {
    const issue = `${rawJiraBody.issue.key} ${rawJiraBody.issue.fields.summary}`;
    const issueUrl = `${JIRA_URL}/browse/${rawJiraBody.issue.key}`
    const author = rawJiraBody.comment.author.displayName;
    const comment = rawJiraBody.comment.body;

    const attachments = [
      {
        fallback: `[<${issueUrl}|${issue}>] commented by ${author}`,
        color: 'good',
        pretext: `[<${issueUrl}|${issue}>] commented by ${author}`,
        title: issue,
        title_link: issueUrl,
        fields: [
          {
            title: "",
            value: rawJiraBody.comment.body,
            short: false
          }
        ],
        footer: author,
        ts: new Date / 1000 | 0
      }
    ]

    return { as_user: true, link_names: 1, attachments: attachments }
  }

  // Jira Account ID から Slack の名前を取得
  // members.coffee みてください
  function fetchSlackUserNameFromJiraAccountID(jiraID) {
    const members = robot.brain.get(BRAIN_KEYS_MEMBERS) || [];

    const member = members.find( m => m.atlassian == jiraID)

    if (member) {
      return member.slack;
    } else {
      return null;
    }
  }

  robot.router.post('/hubot/jira-comment-dm', (req, res) => {
    // リクエストはさっさと返す
    res.send('OK');

    // コメントの内容からメンションを抽出
    const mentionedJiraIDs = extractHandleName(req.body.comment.body);

    // DM 送る用のオプション(Slackのみで動作確認)
    const dmOption = makeSlackOptions(req.body)

    mentionedJiraIDs
       // jira acount id => slack name に変換
      .map(jiraID => fetchSlackUserNameFromJiraAccountID(jiraID))
      // それぞれにDMを送信
      .forEach(slackName => sendDM(slackName, 'あなた宛のコメントがあります。確認しましょう！', dmOption));
  })
}
