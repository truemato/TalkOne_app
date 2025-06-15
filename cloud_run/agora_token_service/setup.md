# Agora Production Setup Guide

## 1. Agoraの本番アプリケーション設定

### Agora Console での設定
1. [Agora Console](https://console.agora.io/) にログイン
2. 新しいプロジェクトを作成または既存プロジェクトを選択
3. プロジェクト設定で「App Certificate」を生成
4. 以下の情報を記録：
   - App ID: `4067eac9200f4aebb0fcf1b190eabd7d` (既に設定済み)
   - App Certificate: (新しく生成される)

## 2. Cloud Run デプロイ手順

### 前提条件
- Google Cloud CLI がインストール済み
- Docker がインストール済み
- Firebase プロジェクトが設定済み

### デプロイ手順
```bash
# プロジェクトに移動
cd cloud_run/agora_token_service

# プロジェクトIDを設定
export PROJECT_ID="your-gcp-project-id"

# Agora認証情報を設定
export AGORA_APP_ID="4067eac9200f4aebb0fcf1b190eabd7d"
export AGORA_APP_CERTIFICATE="your_app_certificate_here"

# Google Cloud認証
gcloud auth login
gcloud config set project $PROJECT_ID

# Docker認証
gcloud auth configure-docker

# デプロイ実行
./deploy.sh
```

## 3. Flutter アプリの設定更新

デプロイ完了後、Flutter側で以下のファイルを更新：

### `lib/config/agora_config.dart`
```dart
// デプロイされたCloud RunのURLに更新
static const String tokenServerUrl = "https://agora-token-service-XXXXX-an.a.run.app";

// 本番証明書を設定
static const String appCertificate = "your_actual_app_certificate";

// 本番モードを有効化
static const bool useTokenAuthentication = true;
```

### `lib/services/agora_token_service.dart`
```dart
// 同じURLに更新
static const String _baseUrl = 'https://agora-token-service-XXXXX-an.a.run.app';
```

## 4. 課金設定と監視

### Firestore コレクション
- `call_records`: トークン生成記録
- `call_end_records`: 通話終了記録（課金計算用）
- `token_refreshes`: トークン更新記録

### 課金監視
```bash
# Cloud Run メトリクス確認
gcloud run services describe agora-token-service --region=asia-northeast1

# Firestore 使用量確認
gcloud firestore operations list
```

## 5. セキュリティ設定

### Firebase Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // call_records: 認証済みユーザーのみ読み取り可能
    match /call_records/{document} {
      allow read: if request.auth != null && request.auth.uid == resource.data.user_id;
      allow write: if false; // サーバーサイドでのみ書き込み
    }
    
    // call_end_records: 管理者のみアクセス可能
    match /call_end_records/{document} {
      allow read, write: if request.auth != null && 
        request.auth.token.admin == true;
    }
  }
}
```

## 6. テスト方法

### ローカルテスト
```bash
# ローカルで起動
python main.py

# トークン生成テスト
curl -X POST http://localhost:8080/agora/token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer firebase_id_token" \
  -d '{
    "channel_name": "test_channel",
    "uid": 12345,
    "user_id": "test_user_id",
    "call_type": "voice"
  }'
```

### 本番テスト
Flutter アプリでマッチングを実行し、以下を確認：
1. トークンが正常に取得される
2. 通話が正常に開始される
3. 通話終了後に課金記録が作成される

## 7. トラブルシューティング

### よくある問題
1. **トークン生成失敗**: App Certificate が正しく設定されているか確認
2. **認証エラー**: Firebase ID トークンが有効か確認
3. **ネットワークエラー**: Cloud Run サービスがデプロイされているか確認

### ログ確認
```bash
# Cloud Run ログ
gcloud run services logs read agora-token-service --region=asia-northeast1

# Flutter ログ
flutter logs
```