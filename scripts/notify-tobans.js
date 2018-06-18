/**
 * Description:
 *   当番お知らせ
 * Configuration:
 *   ROOM_NAME_FOR_TOBANS 通知先の部屋
 *   BRAIN_KEY_FOR_TOBANS 当番のデータ格納カラム名
 *   CRON_TIME_FOR_TOBANS 当番ののお知らせ時間
 * Dependencies:
 *   "cron": "^1.3.0"
 * Commands:
 *   hubot toban ls - 当番のリストを見る
 *   hubot toban add <name> <group_name> - 当番を追加する
 *   hubot toban rm  <name> <group_name> - 当番を削除する
 */


const {CronJob} = require('cron')

const ROOM_NAME = process.env.ROOM_NAME_FOR_TOBANS
const REDIS_KEY = process.env.BRAIN_KEY_FOR_TOBANS
const CRON_TIME = process.env.CRON_TIME_FOR_TOBANS

/**
 *  データ構造はこんな感じ
 * {
 *   groupOne: {
 *     members: ['hoge', 'fuga', 'piyo'],
 *     next: 1, #-> next fuga!
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

    robot.brain.set(REDIS_KEY, tobans)
    res.send(`removed ${name} from ${group}`);
  });

  // 朝にお知らせする
  new CronJob(CRON_TIME, () => {
    const tobans = robot.brain.get(REDIS_KEY) || {}

    // 各当番のお知らせ
    for (const groupName in tobans) {
      const targetGroup = tobans[groupName];

      if (targetGroup.members.length < 1) continue;

      let message = '';

      // 当番をみつけ、次の当番をbrainに保存するように破壊的にインクリメントする
      if(targetGroup.members[targetGroup.index]) {
        message = `今日の${groupName}当番は: @${targetGroup.members[targetGroup.index]}`
        targetGroup.index++;
      } else {
        message = `今日の${groupName}当番は: @${targetGroup.members[0]}`
        targetGroup.index = 1;
      }
      robot.messageRoom(ROOM_NAME, message);
    }
    robot.brain.set(REDIS_KEY, tobans);
  }, null, true);
};
