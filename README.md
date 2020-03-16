# neko


neko は tsukulink の hubot です。

## 開発セットアップ

```bash
yarn install
yarn run start
```

環境変数は `.env` ファイルを作ってそこに書いてください。 `yarn run start` で起動すると読み込まれます

`.env` の例

```env:.env
HOGE_TOKEN=hogehoge
HOGE_DOMAIN=hogehoge.example.org
```

外部サービスの Webhook で連携する時は ngrok 使うと便利

```bash
brew cask install ngrok
ngrok http 8080
```

