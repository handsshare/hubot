// Description:
//   電車遅延お知らせ
// Configuration:
//   ROOM_NAME_FOR_DELAYED_TRAIN 通知先の部屋
//   CRON_TIME_FOR_DELAYED_TRAIN お知らせ時間
// Dependencies:
//   "axios": "^0.18.0"
//   "cheerio": "^1.0.0-rc.2",
//   "cron": "^1.3.0"
// Commands:
//   hubot train - 電車遅延情報表示
const {CronJob} = require('cron');
const cheerio = require('cheerio');
const axios = require('axios');
const ROOM_NAME = process.env.ROOM_NAME_FOR_DELAYED_TRAIN
const CRON_TIME = process.env.CRON_TIME_FOR_DELAYED_TRAIN
const listURL = 'https://transit.yahoo.co.jp/traininfo/area/4/';

const fetchDetail = async (url) => {
  const html = await axios(url);
  const $ = cheerio.load(html.data);
  const title = $('h1.title').text();
  const body = $('.trouble').text().trim();
  return `${title}: ${body}`;
};

const fetchURLsFromList = async (url) => {
  const html = await axios(url);
  const $ = cheerio.load(html.data);
  const detailURLs = $('.trouble  tr:not(:first-child)').map((index, el) => {
    return $(el).find('td:nth-child(1) a').attr('href');
  }).get();
  return detailURLs;
};

module.exports = async (robot) => {
  robot.respond(/train/, async (res) => {
    res.send(`運行状況をチェックします...`);
    try {
      const detailURLs = await fetchURLsFromList(listURL);
      detailURLs.forEach(async url => {
        const detail = await fetchDetail(url);
        res.send(detail);
      });
    } catch(e) {
      res.send(`わかりませんでした。ご自身でチェックしてください ${listURL}`);
      console.error(e);
    }
  });

  if (CRON_TIME) {
    new CronJob(CRON_TIME, async () => {
      const detailURLs = await fetchURLsFromList(listURL);
      detailURLs.forEach(async url => {
        const detail = await fetchDetail(url);
        robot.messageRoom(ROOM_NAME, detail);
      });
    }, null, true);
  }
};
