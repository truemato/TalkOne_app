# Agora音声通話セットアップガイド

## 1. Agoraアカウント作成とプロジェクト設定

### ブラウザで行う作業：

1. **Agoraコンソールにアクセス**
   - https://console.agora.io/ にアクセス
   - アカウントを作成またはログイン

2. **新規プロジェクトを作成**
   - 「Project Management」→「Create」をクリック
   - プロジェクト名: `TalkOne`
   - 認証モード: `Testing mode: APP ID` を選択（開発時）
   - 地域: `Asia Pacific` を選択

3. **App IDを取得**
   - プロジェクトが作成されたら、App IDをコピー
   - 例: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`

4. **音声通話の設定**
   - 「Features」→「Real-time Voice」を有効化
   - 「Channel Management」で以下を設定：
     - Max users per channel: 2（1対1通話）
     - Audio quality: High (48kHz)

## 2. 本番環境用のセキュリティ設定（重要）

### App Certificateの有効化（本番前に必須）

1. **Project Settings**にアクセス
2. **Primary Certificate**をクリック
3. **Enable**をクリックしてApp Certificateを生成
4. Certificate文字列を安全に保管

### トークン認証サーバーの実装が必要な理由：
- App IDのみの認証は開発用
- 本番環境では必ずトークン認証を使用
- トークンには有効期限を設定可能

## 3. 使用量とコスト管理

### 無料枠：
- 10,000分/月の無料通話時間
- 同時接続数: 無制限

### 使用量モニタリング：
1. **Analytics**→**Usage**で確認
2. **Billing**→**Set Alert**で上限アラート設定

## 4. 推奨設定

### 音声品質の最適化：
```
Audio Profile: MUSIC_HIGH_QUALITY_STEREO
Audio Scenario: CHATROOM_ENTERTAINMENT
```

### エコーキャンセレーション：
- AEC (Acoustic Echo Cancellation): 有効
- NS (Noise Suppression): 有効
- AGC (Automatic Gain Control): 有効

## 5. テスト用Web Demo

Agoraが提供するWebデモで接続テスト：
1. https://webdemo.agora.io/basicVoiceCall/index.html
2. あなたのApp IDを入力
3. 同じチャンネル名で2つのブラウザタブから接続
4. 音声通話が正常に動作することを確認

## 6. Firebaseとの連携設定

Cloud Functionsでトークンサーバーを実装する場合：
1. Firebase Console→Functions
2. 環境変数にAgora認証情報を設定：
   ```
   firebase functions:config:set agora.app_id="YOUR_APP_ID"
   firebase functions:config:set agora.certificate="YOUR_CERTIFICATE"
   ```

## 7. 必要な権限設定

### iOS (Info.plist)：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>音声通話のためにマイクを使用します</string>
```

### Android (AndroidManifest.xml)：
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

## トラブルシューティング

### よくある問題：

1. **音声が聞こえない**
   - マイク権限を確認
   - 正しいApp IDを使用しているか確認
   - チャンネル名が一致しているか確認

2. **エコーが発生する**
   - イヤホンの使用を推奨
   - エコーキャンセレーション設定を確認

3. **接続が不安定**
   - ネットワーク品質を確認
   - 地域設定が適切か確認