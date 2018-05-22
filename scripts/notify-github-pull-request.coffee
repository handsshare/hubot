# Description:
#   プルリクお知らせ
#
# Configuration:
#   GITHUB_TOKEN
#   REPO_OWNER
#   REPO_NAME
#   DEVELOPER_ROOM_NAME
#
# Dependencies:
#   "@octokit/rest": "^14.0.9"
#   "cron": "^1.3.0"
#
# Commands:
#   hubot prs - プルリクお知らせ

octokit = require('@octokit/rest')()
{CronJob} = require 'cron'

octokit.authenticate
  type: 'token'
  token: process.env.GITHUB_TOKEN

translate = (word) ->
  translation =
    APPROVED: "承認"
    COMMENTED: "コメント"
    CHANGES_REQUESTED: "改善アドバイス"
    DISMISSED: "却下"
  translation[word] or word

# プルリクを取得する
checkPullRequests = (filters)-> new Promise (resolve, reject) ->
  {filtering, iterator} = Object.assign {iterator:((v) -> v), filtering:( -> true)}, filters
  pullRequests = null

  octokit.pullRequests.getAll
    owner: process.env.REPO_OWNER
    repo: process.env.REPO_NAME
    state: 'open'
    sort: "updated"
    direction: "desc"
  .then (result) ->
    pullRequests = result.data

    # 各プルリクのレビューの詳細を取得
    promises = pullRequests.map (pr)->
      fetchLastReviewStates pr.number, pr.user.login

    Promise.all promises
  .then (result) ->
    resolve pullRequests
      .filter(filtering)
      .map(iterator)
      .map (pr, index)->
        reviewersState = result.find((reviewState)-> reviewState.number is pr.number).reviewersState
        prettyPRReviews(pr, reviewersState)

  .catch (result) ->
    reject result

# レビュー中レビュワーの最新状態を取得する
# return: {"user1": "APPROVED", "user2": "COMMENTED"...}
fetchLastReviewStates = (number, reviewee)-> new Promise (resolve, reject) ->
  octokit.pullRequests.getReviews
    owner: process.env.REPO_OWNER
    repo: process.env.REPO_NAME
    number: number
  .then (result) ->
    reviewersState = result.data
      .map (d) ->
        [d.user.login, d.state]
      .reduce((sum, [userName, state]) ->
        # レビュイー自身は飛ばす
        if userName isnt reviewee
          sum[userName] = state
        sum
      , {})
    resolve {number, reviewersState}

  .catch (e)-> reject e

# プルリクレビュー状態を人が読めるようにする
# pr: raw pull request object from GitHub API
# reviewersState: {"user1": "APPROVED", "user2": "COMMENTED"...}
prettyPRReviews = (pr, reviewersState)->
  #prettied = [":octocat: #{pr.user.login} のプルリク「#{pr.title}」(#{pr.html_url})"]
  prettied = [":octocat: 「#{pr.title}」(#{pr.html_url})"]

  requestedReviewers = pr.requested_reviewers.map (u) -> u.login
  for userName in requestedReviewers
    prettied.push "| @#{slackName(userName)} のレビューを待ってるよ！"

  approvedCount = 0
  changesRequestedCount = 0
  for userName, state of reviewersState
    if state is "APPROVED"
      approvedCount += 1
      # 承認済みの人にはメンションしない
      #prettied.push  "| #{userName} が#{translate state}したよ！"
    if state is "CHANGES_REQUESTED"
      changesRequestedCount += 1
    #else
    #  prettied.push "| #{userName} が#{translate state}したよ！"

  if (requestedReviewers.length is 0) and (approvedCount isnt 0) and (approvedCount is Object.keys(reviewersState).length)
    prettied.push "| @#{slackName(pr.user.login)} 全員承認したよ！マージしましょう！"
  if changesRequestedCount > 0
    prettied.push "| @#{slackName(pr.user.login)} 変更リクエストがあるよ！確認しましょう！"

  prettied.join('\n')

# FIXME
slackName = null

module.exports = (robot) ->
  BRAIN_KEYS_MEMBERS = 'members'
  slackName = (githubName)->
    members = robot.brain.get(BRAIN_KEYS_MEMBERS) or []
    member = members.find ({github})-> github is githubName
    member?.name or githubName

  robot.respond /prs/i, (res) ->
    res.send 'プルリクチェックします...'
    checkPullRequests().then (messages) ->
      if messages.length isnt 0
        res.send messages.join("\n")
      else
        res.send "オープンなプルリクはありません"
    .catch (e) ->
      res.send "失敗しました"
      console.error e

  new CronJob '0 0,30 10-18 * * 1-5', ->
    filtering = ({title})-> not title.startsWith('(wip)')

    iterator = (pr)->
      # Jiraのボットにチケット番号拾われてしまう問題
      sanitizedTitle = pr.title.replace(/TSUK-(\d+)/, 'xTSUK-$1')
      Object.assign(pr, {title: sanitizedTitle})

    checkPullRequests({iterator, filtering}).then (messages)->
      messages.forEach (message)-> robot.messageRoom process.env.DEVELOPER_ROOM_NAME, message
  , null, true
