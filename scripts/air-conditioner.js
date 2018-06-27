// Description:
//   空調の具合を訪ねる
// Configuration:
//   ROOM_NAME_FOR_AIR_CON
//   CRON_TIME_FOR_ARI_CON
// Dependencies:
//   "cron": "^1.3.0"
const {CronJob} = require('cron')

const ROOM_NAME = process.env.ROOM_NAME_FOR_AIR_CON
const CRON_TIME = process.env.CRON_TIME_FOR_AIR_CON || '* 0,30 10-18 * * 1-5'

module.exports = (robot) => {

console.log(CRON_TIME);
  new CronJob(CRON_TIME, () => {
    const message = `
エアコンの設定温度をリアクションしてください
あげたい :arrow_up_small:  \`:arrow_up_small\`
そのまま :black_square_for_stop:  \`:black_square_for_stop:\`
さげたい :arrow_down_small:   \`:arrow_down_small\`
    `
    robot.messageRoom(ROOM_NAME, message);
  }, null, true);
};
