# macOS App Icon 更新

RC2のAbout画面で使用しているシンプルなストップウォッチデザインを基に、正式なmacOS App Iconセットへ差し替えています。

## 更新箇所

- `assets/icons/show_time_app_icon.png`：1024×1024マスター
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/`：16〜1024pxのmacOS用PNG一式
- `lib/widgets/about_dialog.dart`：About画面も同じ画像資産を使用
- `pubspec.yaml`：画像資産を登録

## 確認コマンド

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build macos --release
open build/macos/Build/Products/Release
```

FinderやDockで旧アイコンが残る場合は、ビルド成果物を削除して再ビルドしてください。必要に応じてFinderまたはDockを再起動します。
