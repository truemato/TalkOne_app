# Agora Token Service

Agora RTCの本番環境用トークン生成サービス（Cloud Run）

## セットアップ

### 1. 必要な依存関係をインストール
```bash
pip install -r requirements.txt
```

### 2. 環境変数を設定
```bash
export AGORA_APP_ID="your_agora_app_id"
export AGORA_APP_CERTIFICATE="your_app_certificate"
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"
```

### 3. ローカルでテスト
```bash
python main.py
```

## デプロイ

### 1. Google Cloud CLIの設定
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Cloud Runにデプロイ
```bash
chmod +x deploy.sh
./deploy.sh
```

### 3. デプロイ後の設定
デプロイが完了したら、サービスURLを以下に設定：

**`lib/config/agora_config.dart`**
```dart
static const String tokenServerUrl = "https://agora-token-service-xxxxx.run.app";
```

**`lib/services/agora_token_service.dart`**
```dart
static const String _baseUrl = 'https://agora-token-service-xxxxx.run.app';
```

## APIエンドポイント

### POST /agora/token
Agoraトークンを生成

**リクエスト：**
```json
{
  "channel_name": "talkone_12345",
  "uid": 123456,
  "user_id": "firebase_user_id",
  "call_type": "voice"
}
```

**レスポンス：**
```json
{
  "success": true,
  "token": "006abc...",
  "expires_in": 3600
}
```

### POST /agora/refresh
トークンを更新

### POST /agora/end_call
通話終了を記録（課金計算用）

## 課金体系

- 音声通話: $0.99/1000分
- ビデオ通話(SD): $3.99/1000分
- ビデオ通話(HD): $8.99/1000分

通話記録は `call_records` および `call_end_records` コレクションに保存されます。

## セキュリティ

- Firebase Authentication必須
- CORS設定でFlutterアプリからのアクセスのみ許可
- トークンの有効期限は1時間
- 通話時間・コスト追跡によりセキュリティと課金を管理