// Description:
//   JIRA のコメントでメンションされたらDMでお知らせする
//   /hubot/jira-comment-dm
//   /hubot/jira-assgined-dm
//
// Configuration:
//   HUBOT_JIRA_URL: JIRAのドメイン
//   JIRA_TOKEN: JIRAのwebhook(?token=your_token)のトークン
//
// Dependencies:
//   "members.coffee": "0.0"
//
// Commands:
//   なし

const BRAIN_KEYS_MEMBERS = 'members';
const JIRA_URL = process.env.HUBOT_JIRA_URL || 'https://jira.example.org';
const TOKEN = process.env.JIRA_TOKEN || 'webhookの方で何かセットしてください';

module.exports = (robot) => {

  // 文字列からJIRAのメンションを抽出して返す
  // @param [String] string eg "[~accountid:hogehogehoge] hello and [~accountid:fugafuga]"
  // @return [Array<String>] eg ["hogehogehoge", "fugafuga"]
  function extractJiraIDs(string) {
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
      return
    }

    client.web.chat.postMessage(user.id, message, options)
  }

  // JiraのコメントのWebHookのbodyから Slack投稿用のオプションを作成する
  function makeSlackOptions(rawJiraBody, type) {
    const issue = `${rawJiraBody.issue.key} ${rawJiraBody.issue.fields.summary}`;
    const issueUrl = `${JIRA_URL}/browse/${rawJiraBody.issue.key}`

    let author = null;
    let fieldValue = null;
    let text = null;

    if (type === 'comment') {
      author = rawJiraBody.comment.author.displayName;
      fieldValue = rawJiraBody.comment.body;
      text = `[<${issueUrl}|${issue}>] commented by ${author}`;
    }

    if (type === 'issue') {
      author = rawJiraBody.user.displayName;
      fieldValue = rawJiraBody.issue.fields.description;
      text = `[<${issueUrl}|${issue}>] assgined by ${author}`;
    }

    const attachments = [
      {
        fallback: text,
        color: 'good',
        pretext: text,
        title: issue,
        title_link: issueUrl,
        fields: [
          {
            title: "",
            value: fieldValue,
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
  function getSlackName(jiraID) {
    const members = robot.brain.get(BRAIN_KEYS_MEMBERS) || [];

    const member = members.find( m => m.atlassian == jiraID)

    if (member) {
      return member.slack;
    } else {
      return null;
    }
  }

  function verifyToken(token) {
    if (token !== TOKEN) {
      throw new Error('トークンが正しくないです。Jira の webhook と hubot の設定を確認してください。');
    }
  }

  // エンドポイント1(メンションのDM通知)
  robot.router.post('/hubot/jira-comment-dm', (req, res) => {
    try {
      verifyToken(req.query.token);
    } catch(e) {
      res.status(403).send('invalid token');
      return;
    }

    res.send('OK');

    // コメントの内容からメンションを抽出
    const mentionedJiraIDs = extractJiraIDs(req.body.comment.body);

    // DM 送る用のオプション(Slackのみで動作確認)
    const dmOption = makeSlackOptions(req.body, 'comment')

    mentionedJiraIDs
       // jira acount id => slack name に変換
      .map(jiraID => getSlackName(jiraID))
      // それぞれにDMを送信
      .forEach(slackName => sendDM(slackName, 'あなた宛のコメントがあります。確認しましょう！', dmOption));
  })

  // エンドポイント2(チケットのアサインお知らせ)
  robot.router.post('/hubot/jira-assign-dm', (req, res) => {
    try {
      verifyToken(req.query.token);
    } catch(e) {
      res.status(403).send('invalid token');
      return;
    }

    // リクエストはさっさと返す
    res.send('OK');

    const body = req.body;

    // アサイン者がいない時はなにもしない
    if (!body.issue.fields.assignee) {
      return;
    }

    // アサイン者変更以外の時はなにもしない
    if (body.webhookEvent === 'jira:issue_updated' && body.changelog.items[0].field !== 'assignee') {
      return;
    }

    const jiraID = body.issue.fields.assignee.accountId;
    const slackName = getSlackName(jiraID);

    if (!slackName) {
      robot.logger.error(`${jiraID}さんがSlack上に存在しません。`)
      return
    }
    const slackOption = makeSlackOptions(body, 'issue');

    sendDM(slackName, 'イシューにアサインされました。確認しましょう！', slackOption);
  });
}
