# VOICEVOX Engine Cloud Run デプロイガイド

VOICEVOX EngineをGoogle Cloud Runにデプロイして、TalkOneアプリから利用するためのガイドです。

## 前提条件

1. Google Cloud Platform (GCP) アカウント
2. Google Cloud SDK (`gcloud`) がインストール済み
3. Docker がインストール済み
4. Container Registry API が有効化済み
5. Cloud Run API が有効化済み

## セットアップ手順

### 1. GCPプロジェクトの設定

```bash
# GCPプロジェクトを作成または選択
gcloud projects create your-project-id  # 新規作成の場合
gcloud config set project your-project-id

# 必要なAPIを有効化
gcloud services enable containerregistry.googleapis.com
gcloud services enable run.googleapis.com
```

### 2. 認証設定

```bash
# Dockerの認証設定
gcloud auth configure-docker
```

### 3. デプロイスクリプトの編集

`deploy.sh` ファイルの `PROJECT_ID` を実際のGCPプロジェクトIDに変更してください：

```bash
PROJECT_ID="your-actual-project-id"  # ここを変更
```

### 4. デプロイ実行

```bash
# スクリプトを実行可能にする
chmod +x deploy.sh

# デプロイ実行
./deploy.sh
```

## デプロイ後の設定

### 1. Flutterアプリの設定更新

デプロイ完了後に表示されるURLを、TalkOneアプリの設定に反映してください：

```dart
// lib/services/voicevox_service.dart
static const String _defaultHost = "https://your-voicevox-service-url.run.app";
```

### 2. CORS設定の確認

WebアプリケーションからVOICEVOX Engineを利用する場合、CORS設定が正しく適用されているか確認してください。

### 3. パフォーマンス調整

本番運用時は以下の設定を調整することを推奨します：

- **メモリ**: 2Gi〜4Gi（音声処理の負荷に応じて）
- **CPU**: 2〜4 vCPU
- **同時実行数**: 80〜100（リクエスト量に応じて）
- **タイムアウト**: 300秒

## コスト最適化

### リクエストベース課金

Cloud Runはリクエストベースの課金です：
- 使用量に応じて課金
- アイドル時は課金されない
- 最小インスタンス数を0に設定可能

### 推定コスト（月間）

- 軽度使用（1,000リクエスト/月）: 約$1-2
- 中程度使用（10,000リクエスト/月）: 約$5-10
- 高使用（100,000リクエスト/月）: 約$20-50

## トラブルシューティング

### デプロイエラー

1. **認証エラー**: `gcloud auth login` で再認証
2. **権限エラー**: IAMロールの確認（Cloud Run Admin、Storage Admin）
3. **API無効化エラー**: 必要なAPIが有効化されているか確認

### 動作確認

```bash
# デプロイされたサービスのURLを取得
SERVICE_URL=$(gcloud run services describe voicevox-engine --region asia-northeast1 --format 'value(status.url)')

# バージョン確認
curl ${SERVICE_URL}/version

# 話者リスト取得
curl ${SERVICE_URL}/speakers
```

## セキュリティ考慮事項

### 本番運用時の推奨設定

1. **認証の追加**: Cloud IAMによるアクセス制御
2. **API制限**: レート制限の実装
3. **ログ監視**: Cloud Loggingでの監視設定
4. **SSL/TLS**: HTTPSの強制（デフォルトで有効）

### API キー認証（オプション）

より厳密なセキュリティが必要な場合、API Keyによる認証を実装することを推奨します。

## 監視とメンテナンス

### Cloud Monitoring

1. リクエスト数の監視
2. レスポンス時間の監視
3. エラー率の監視
4. メモリ・CPU使用率の監視

### 定期メンテナンス

1. VOICEVOX Engineの更新確認
2. セキュリティパッチの適用
3. パフォーマンス最適化

## サポート

- [VOICEVOX公式ドキュメント](https://voicevox.hiroshiba.jp/)
- [Google Cloud Run ドキュメント](https://cloud.google.com/run/docs)
- [Container Registry ドキュメント](https://cloud.google.com/container-registry/docs)