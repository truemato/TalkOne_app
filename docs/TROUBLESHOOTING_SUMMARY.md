# TalkOne トラブルシューティング記録

## 実施日時
2025年6月15日

## 問題と解決の要約

### 1. 実機での白い画面問題

#### 問題の症状
- iPhoneで実行時に白い画面のまま起動しない
- Dart VM Service への接続失敗エラー
- `Connecting to VM Service at ws://127.0.0.1:57741/xxxxxx/ws` でタイムアウト

#### 根本原因
**Firebase Bundle ID の不一致**
- `GoogleService-Info.plist` のBundle IDが `com.example.flutterTemp`
- プロジェクトのBundle IDは `com.talkone.app`
- この不一致によりFirebase初期化が失敗

#### 解決方法
1. `ios/Runner/GoogleService-Info.plist` を編集
   ```xml
   <key>BUNDLE_ID</key>
   <string>com.talkone.app</string>  <!-- 修正 -->
   ```

2. ローカルネットワーク権限を追加（Info.plist）
   ```xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>This app uses local network for development debugging</string>
   <key>NSBonjourServices</key>
   <array>
     <string>_dartobservatory._tcp</string>
     <string>_flutter._tcp</string>
   </array>
   ```

### 2. Pod関連のビルドエラー

#### 問題
`Framework 'Pods_Runner' not found` エラー

#### 解決方法
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean
flutter pub get
```

### 3. ネットワーク接続エラー

#### 問題
`[firebase_auth/network-request-failed] Network error` 

#### 解決方法
ネットワーク接続確認画面を実装
- 起動時に接続状態を確認
- 失敗時はリトライボタンを表示
- 成功時は自動的にホーム画面へ遷移

## ビルド時間の改善

### 問題
ビルド時間が長い（2-3分以上）

### 原因
- 41個のPod依存関係
- デバッグモードのオーバーヘッド
- iOS 26.0 Beta環境

### 改善策
```bash
# リリースモードで実行（高速）
flutter run --release

# ビルド時間の比較
# デバッグモード: 約168秒
# リリースモード: 約35秒（約80%高速化）
```

## コマンドリファレンス

### 基本的なトラブルシューティング
```bash
# 1. 完全クリーンビルド
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
cd ios && pod install && cd ..

# 2. デバイス確認
flutter devices

# 3. 詳細ログ付きビルド
flutter run -v

# 4. リリースモードビルド（高速）
flutter run --release
```

### Xcodeからの実行
```bash
# Xcodeプロジェクトを開く
open ios/Runner.xcworkspace
```

## 環境情報
- **Flutter**: 3.32.2
- **Dart**: 3.8.1
- **Xcode**: 16.4
- **iOS**: 26.0 (Beta)
- **デバイス**: iPhone (4 years old)
- **macOS**: 15.4.1

## 重要な設定ファイル

### Bundle ID統一
すべてのプラットフォームで `com.talkone.app` に統一：
- `ios/Runner.xcodeproj/project.pbxproj`
- `android/app/build.gradle.kts`
- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`

### iOS最小バージョン
- iOS 13.0（AI filterサポートのため）
- `ios/Podfile`: `platform :ios, '13.0'`

## 学んだ教訓
1. **Firebase設定の確認**: Bundle IDの不一致は白い画面の原因になる
2. **Pod管理**: 定期的なクリーンアップが必要
3. **ビルドモード**: 開発中でもリリースモードの使用を検討
4. **エラーハンドリング**: ネットワークエラーは適切に処理する必要がある
5. **権限設定**: iOS 14+ではローカルネットワーク権限が必要