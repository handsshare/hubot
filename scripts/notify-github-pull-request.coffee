# Description:
#   プルリクお知らせ
#
# Configuration:
#   GITHUB_TOKEN
#   REPO_PATHS "owner_name/repo_name_1,owner_name/repo_name_2,other_owner_name/repo_name_3"
#   DEVELOPER_ROOM_NAME
#   CRON_TIME_FOR_GITHUB_PULL_REQUEST
#
# Dependencies:
#   "@octokit/rest": "^14.0.9"
#   "cron": "^1.3.0"
#   "lodash": "^4.17.10"
#
# Commands:
#   hubot prs - プルリクお知らせ

CRON_TIME_FOR_GITHUB_PULL_REQUEST = process.env.CRON_TIME_FOR_GITHUB_PULL_REQUEST ||  '0 0,30 10-18 * * 1-5'
octokit = require('@octokit/rest')()
{CronJob} = require 'cron'
_ = require 'lodash'

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

# ower_name/repo_name1,ower_name/repo_name2,...
repoPaths = process.env.REPO_PATHS.split(',')
  .map (path)->
    path.split('/')
  .map ([owner, repo]) ->
    {owner, repo}

checkPullRequestsAll = (filters) -> new Promise (resolve, reject)->
  promises = repoPaths.map ({repo, owner})-> checkPullRequests({owner, repo, filters})
  Promise.all(promises)
    .then (results) ->
      resolve _.flatten(results)
    .catch (results) ->
      resolve results

# プルリクを取得する
checkPullRequests = ({owner, repo, filters})-> new Promise (resolve, reject) ->
  {filtering, iterator} = Object.assign {iterator:((v) -> v), filtering:( -> true)}, filters
  pullRequests = null

  octokit.pullRequests.getAll
    owner: owner
    repo: repo
    state: 'open'
    sort: "updated"
    direction: "desc"
  .then (result) ->
    pullRequests = result.data

    # 各プルリクのレビューの詳細を取得
    promises = pullRequests.map (pr)->
      fetchLastReviewStates owner, repo, pr.number, pr.user.login

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
fetchLastReviewStates = (owner, repo, number, reviewee)-> new Promise (resolve, reject) ->
  octokit.pullRequests.getReviews
    owner: owner
    repo: repo
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
    if state in ["CHANGES_REQUESTED", "COMMENTED"]
      changesRequestedCount += 1
    #else
    #  prettied.push "| #{userName} が#{translate state}したよ！"

  if (requestedReviewers.length is 0) and (approvedCount isnt 0) and (approvedCount is Object.keys(reviewersState).length)
    prettied.push "| @#{slackName(pr.user.login)} 全員承認したよ！マージしましょう！"
  if changesRequestedCount > 0
    prettied.push "| @#{slackName(pr.user.login)} レビューコメントがあるよ！確認しましょう！"

  # マージ先警告
  # TODO: 別に切り出したい
  if shouldAlertMargeBase(pr.base.ref, pr.head.ref)
    prettied.push "@#{slackName(pr.user.login)} マージ先がおかしいっぽいので確認してください。 #{pr.head.ref} -> #{pr.base.ref}"

  prettied.filter((p) -> p? ).join('\n')

# マージ先が変な時に警告する
#
# TODO: 別スクリプトにする
shouldAlertMargeBase = (baseName, headName) ->
  whiteList = [
    {base: 'master', head: ['feature/', 'hotfix/', 'fix/', 'parent/']},
    {base: 'parent/', head: ['child/', 'feature/']},
    {base: 'feature/', head: ['child/']},
    {base: 'release', head: ['hotfix/', 'master']},
  ]
  ok = whiteList.filter (white) ->
    baseName.startsWith(white.base) and (white.head.filter (item) -> headName.startsWith(item)).length isnt 0

  ok.length is 0

#assert shouldAlertMargeBase 'master', 'parent/hoge'
#assert shouldAlertMargeBase 'master', 'hotfix/hoge'
#assert shouldAlertMargeBase 'master', 'fix/hoge'
#assert shouldAlertMargeBase 'master', 'feature/hoge'
#assert shouldAlertMargeBase 'release', 'master'
#assert shouldAlertMargeBase 'release', 'hotfix/hoge'
#assert shouldAlertMargeBase 'parent/guga', 'child/hoge'
#assert not shouldAlertMargeBase 'master', 'child/hoge'
#assert not shouldAlertMargeBase 'release', 'feature/hoge'
#assert not shouldAlertMargeBase 'release', 'parent/hoge'
#assert not shouldAlertMargeBase 'parent/guga', 'hotfix/hoge'
#assert not shouldAlertMargeBase 'parent/guga', 'feature/munya'

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
    checkPullRequestsAll().then (messages) ->
      if messages.length isnt 0
        res.send messages.join("\n")
      else
        res.send "オープンなプルリクはありません"
    .catch (e) ->
      res.send "失敗しました"

  new CronJob CRON_TIME_FOR_GITHUB_PULL_REQUEST, ->
    filtering = ({title})-> not title.toLowerCase().startsWith('(wip)') and not title.toLowerCase().startsWith('(ok)')

    iterator = (pr)->
      # Jiraのボットにチケット番号拾われてしまう問題
      sanitizedTitle = pr.title.replace(/TSUK-(\d+)/, 'xTSUK-$1')
      Object.assign(pr, {title: sanitizedTitle})

    checkPullRequestsAll({iterator, filtering}).then (messages)->
      messages.forEach (message)-> robot.messageRoom process.env.DEVELOPER_ROOM_NAME, message
  , null, true
