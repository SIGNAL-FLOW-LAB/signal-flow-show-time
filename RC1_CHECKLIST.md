# SIGNAL FLOW Show Time v1.0.0 RC1 — 動作確認

## 起動前

```bash
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d macos
```

## 基本操作

- [ ] STARTで計測開始
- [ ] PAUSEで一時停止
- [ ] RESUMEで継続
- [ ] HOLD RESETを短押ししてもリセットされない
- [ ] HOLD RESETを長押しすると00:00:00へ戻る
- [ ] SpaceでSTART / PAUSE / RESUME

## タイトル

- [ ] タイトルをクリックして編集
- [ ] スペースを入力可能
- [ ] Enterで保存
- [ ] 緑のチェックで保存
- [ ] ×でキャンセル
- [ ] 再起動後も保存内容が残る

## 設定

- [ ] 日本語 / English切替
- [ ] 現在時刻表示ON / OFF
- [ ] 秒表示ON / OFF
- [ ] 24時間表記ON / OFF
- [ ] Always on Top
- [ ] 再起動後も設定が残る

## macOSメニュー

- [ ] メニューを開いてもすぐ閉じない
- [ ] ⌘, で設定を開く
- [ ] Escで設定を閉じる
- [ ] 言語切替が画面と同期
- [ ] Always on Topが画面と同期
- [ ] 日本語時「SIGNAL FLOW Show Timeを終了」
- [ ] English時「Quit SIGNAL FLOW Show Time」
- [ ] ⌘Qで終了

## レイアウト

- [ ] 最小ウインドウでRESUMEが中央1行
- [ ] 最大化しても表示崩れなし
- [ ] タイマー動作中もメニューが安定
