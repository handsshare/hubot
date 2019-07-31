// Description:
//   真夏日お知らせ
// Configuration:
//   TENKI_ROOM_NAME
//   TENKI_CRON_TIME
//   TENKI_URL tenki.jp の URL
// Dependencies:
//   "axios": "^0.18.0"
//   "cheerio": "^1.0.0-rc.2",
//   "cron": "^1.3.0"
const {CronJob} = require('cron');
const cheerio = require('cheerio');
const axios = require('axios');

const ROOM_NAME = process.env.SUMMER_ROOM_NAME;
const CRON_TIME = process.env.SUMMER_CRON_TIME;
const SUMMER_URL = process.env.SUMMER_URL;

const fetchTemplature = async (url) => {
  const html = await axios(url);
  const $ = cheerio.load(html.data);
  const place = $('.section-wrap h2').text().trim();
  const highTemp = $('.today-weather .high-temp .value').text();
  const lowTemp = $('.today-weather .low-temp .value').text();
  const weather = $('.today-weather .weather-telop').text();
  return { place, highTemp, lowTemp, weather }
}

const message = (temp) => {
  return `本日の${temp.place}は${temp.weather}${gobi.random()}。\
最高気温は${temp.highTemp}℃ , 最低気温は${temp.lowTemp}℃${gobi.random()}。\
${uranai.random()}${gobi.random()}。`
}

const gobi = ['です', 'ですね', 'ですのよ', 'でごわす', 'ですなあ', 'でしょう'];
const uranai = ['あつい', 'すごしやすい', '行楽日和', '肌寒い', '運勢は大吉'];

module.exports = (robot) => {

  robot.respond(/atsui/i, async (res) => {
    const temp = await fetchTemplature(SUMMER_URL);
    res.send(message(temp));
  })

  if (CRON_TIME) {
    new CronJob(CRON_TIME, async () => {
      const temp = await fetchTemplature(SUMMER_URL);
      robot.messageRoom(ROOM_NAME, message(temp));
    }, null, true);
  }
};
