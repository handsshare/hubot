// Description:
//   当番お知らせ
// Configuration:
//   ROOM_NAME_FOR_TOBANS 通知先の部屋(複数の場合、カンマ区切り)
//   BRAIN_KEY_FOR_TOBANS 当番のデータ格納キー名
//   CRON_TIME_FOR_TOBANS_NEXT 当番の更新&お知らせ時間
//   CRON_TIME_FOR_TOBANS_REPRISE 当番のお知らせ時間(再確認)
// Dependencies:
//   "cron": "^1.3.0"
// Commands:
//   hubot toban ls - 当番のリストを見る
//   hubot toban add <name> <group_name> - 当番を追加する
//   hubot toban rm  <name> <group_name> - 当番を削除する
const {CronJob} = require('cron')

const ROOM_NAMES = process.env.ROOM_NAME_FOR_TOBANS.split(',')
const REDIS_KEY = process.env.BRAIN_KEY_FOR_TOBANS
const CRON_TIME_FOR_TOBANS_NEXT = process.env.CRON_TIME_FOR_TOBANS_NEXT
const CRON_TIME_FOR_TOBANS_REPRISE = process.env.CRON_TIME_FOR_TOBANS_REPRISE

/**
 *  データ構造はこんな感じ
 * {
 *   groupOne: {
 *     members: ['hoge', 'fuga', 'piyo'],
 *     index: 1, #-> now fuga!
 *   },
 *   ...
 * }
 *
 */

module.exports = (robot) => {

  // 当番一覧
  robot.respond(/toban ls/, (res) => {
    const tobans = robot.brain.get(REDIS_KEY) || {}
    for (const groupName in tobans) {
      const target = tobans[groupName];
      const prettied = target.members
        .map((name, index) => target.index === index ? `*${name}*` : name)
        .join(' -> ');
      res.send(`${groupName}: ${prettied}`);
    }
  });

  // 当番追加
  robot.respond(/toban add (\S+)\s(\S+)/, (res) => {
    const name = res.match[1].trim()
    const group = res.match[2].trim()

    const tobans = robot.brain.get(REDIS_KEY) || {}

    // まだ当番がない場合は作成
    if (!tobans[group]) {
      tobans[group] = {
        members: [],
        index: 0
      };
    }

    tobans[group].members.push(name)
    robot.brain.set(REDIS_KEY, tobans)
    res.send(`added ${name} to ${group}`);
  });

  // 当番削除
  robot.respond(/toban rm (\S+)\s(\S+)/, (res) => {
    const name = res.match[1].trim()
    const group = res.match[2].trim()

    const tobans = robot.brain.get(REDIS_KEY) || {}
    const target = tobans[group]

    if (!target) {
      res.send(`Not found ${group}`);
      return
    }

    target.members = target.members.filter(memberName => memberName !== name);
    if (target.members.length === 0) delete tobans[group]

    robot.brain.set(REDIS_KEY, tobans)
    res.send(`removed ${name} from ${group}`);
  });

  // 当番を更新してお知らせ
  if (CRON_TIME_FOR_TOBANS_NEXT) {
    new CronJob(CRON_TIME_FOR_TOBANS_NEXT, () => {
      const tobans = robot.brain.get(REDIS_KEY) || {}

      // 各当番のお知らせ
      for (const groupName in tobans) {
        const targetGroup = tobans[groupName];

        if (targetGroup.members.length < 1) continue;


        // 次の当番をbrainに保存するように破壊的にインクリメントする
        targetGroup.index++;

        // 一周したら先頭から
        if (!targetGroup.members[targetGroup.index]) {
          targetGroup.index = 0;
        }

        let message = `今日の${groupName}当番は: @${targetGroup.members[targetGroup.index]}`
        for (const room_name in ROOM_NAMES) {
          robot.messageRoom(room_name, message);
        }
      }
      robot.brain.set(REDIS_KEY, tobans);
    }, null, true);
  }


  // 繰り上げずにお知らせだけする
  if (CRON_TIME_FOR_TOBANS_REPRISE) {
    new CronJob(CRON_TIME_FOR_TOBANS_REPRISE, () => {
      const tobans = robot.brain.get(REDIS_KEY) || {}
      for (const groupName in tobans) {
        const targetGroup = tobans[groupName];
        if (targetGroup.members.length < 1) continue;

        let message = `今日の${groupName}当番は @${targetGroup.members[targetGroup.index]} でした. お疲れ様でした. `
        for (const room_name in ROOM_NAMES) {
          robot.messageRoom(room_name, message);
        }
      }
    }, null, true);
  }
};
