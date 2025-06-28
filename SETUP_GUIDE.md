# TalkOne セットアップガイド

## 🔐 プライベート設定ファイルの準備

新しい環境でTalkOneを動作させるために、以下のプライベート設定ファイルを準備する必要があります。

### 1. Firebase設定

#### Firebase プロジェクト作成
1. [Firebase Console](https://console.firebase.google.com/) でプロジェクト作成
2. Authentication、Firestore、AI機能を有効化
3. iOS・Android・Webアプリを追加

#### 設定ファイル配置
```bash
# テンプレートをコピー
cp lib/firebase_options.dart.template lib/firebase_options.dart

# FlutterFire CLIで自動生成（推奨）
flutterfire configure
```

**手動設定の場合:**
- `lib/firebase_options.dart` - YOUR_XXX_XXX部分を実際の値に置換
- `ios/Runner/GoogleService-Info.plist` - Firebaseコンソールからダウンロード
- `android/app/google-services.json` - Firebaseコンソールからダウンロード

### 2. 環境変数設定

```bash
# テンプレートをコピー
cp .env.template .env

# .envファイルを編集
AGORA_APP_ID=your_actual_agora_app_id
VOICEVOX_ENGINE_URL=your_voicevox_endpoint
```

### 3. Bundle ID 設定

#### iOS設定
`ios/Runner/Info.plist` で以下を変更:
```xml
<key>CFBundleIdentifier</key>
<string>YOUR_BUNDLE_ID</string>

<key>CFBundleURLSchemes</key>
<array>
    <string>YOUR_GOOGLE_SIGNIN_URL_SCHEME</string>
</array>
```

#### Android設定
`android/app/build.gradle` で以下を変更:
```gradle
defaultConfig {
    applicationId "YOUR_BUNDLE_ID"
}
```

### 4. Apple Developer設定

#### 必要な作業
1. [Apple Developer Console](https://developer.apple.com/) でApp ID作成
2. Bundle ID: `YOUR_BUNDLE_ID` で登録
3. 必要なCapabilities追加:
   - Push Notifications
   - Sign In with Apple
   - Background Modes (audio, voip)

#### Xcodeでの設定
1. `ios/Runner.xcworkspace` を開く
2. Signing & Capabilities タブ
3. Team とBundle Identifier を設定

### 5. 依存関係インストール

```bash
# Flutter依存関係
flutter pub get

# iOS CocoaPods
cd ios && pod install && cd ..

# Android依存関係（自動）
flutter build apk --debug
```

## 🔧 ビルド・実行

### デバッグビルド
```bash
# Flutter実行
flutter run

# iOS
flutter run -d ios

# Android
flutter run -d android
```

### リリースビルド
```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release
```

## ⚠️ 重要な注意事項

### セキュリティ
- **絶対に** `.env` や `firebase_options.dart` をGitに含めない
- API キーは定期的に更新する
- 本番環境では適切なFirebaseセキュリティルールを設定

### 必須設定項目
- [x] Firebase プロジェクト設定
- [x] Bundle ID 設定
- [x] Agora App ID 設定
- [x] Apple Developer App ID 作成
- [x] Google Sign-In 設定

### テスト前チェックリスト
- [x] Firebase認証動作
- [x] Firestore読み書き
- [x] 音声通話機能
- [x] AI機能（Gemini）
- [x] VoiceVox音声合成

## 🆘 トラブルシューティング

### よくある問題
1. **Firebase初期化エラー** → 設定ファイルの内容確認
2. **iOS証明書エラー** → Apple Developer Console設定確認
3. **Android権限エラー** → AndroidManifest.xml権限確認
4. **Agora接続エラー** → App ID・トークン確認

### ヘルプ
- Firebase: [公式ドキュメント](https://firebase.google.com/docs)
- Agora: [公式ドキュメント](https://docs.agora.io/)
- Flutter: [公式ドキュメント](https://flutter.dev/docs)

---

**注**: このガイドに従って設定することで、TalkOneアプリの完全な動作環境を構築できます。