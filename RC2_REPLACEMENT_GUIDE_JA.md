# RC2 丸ごと入れ替え手順

このZIPにはGit履歴（`.git`）とビルド生成物を含めていません。
既存GitHub接続を維持するため、現在の `show_time` フォルダへ内容だけを反映してください。

## 1. バックアップ

```bash
cd ~/Documents/SignalFlowApps
cp -R show_time show_time_backup_before_rc2
```

## 2. RC2を展開

ZIPを `SignalFlowApps` 内へ展開し、フォルダ名が
`SIGNAL_FLOW_Show_Time_v1.0.0_RC2` になっていることを確認します。

## 3. 既存リポジトリへ内容を反映

```bash
cd ~/Documents/SignalFlowApps
rsync -av --delete \
  --exclude='.git/' \
  --exclude='.dart_tool/' \
  --exclude='build/' \
  --exclude='.DS_Store' \
  SIGNAL_FLOW_Show_Time_v1.0.0_RC2/ show_time/
```

## 4. 検証

```bash
cd show_time
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d macos
```

## 5. 動作確認後のGit操作

```bash
git status
git add .
git commit -m "Release v1.0.0 RC2"
git push
git tag v1.0.0-rc.2
git push origin v1.0.0-rc.2
```

必ずアプリの起動・About表示・基本タイマー操作を確認してからタグを作成してください。
