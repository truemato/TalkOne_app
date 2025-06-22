#!/bin/bash

# VOICEVOX TTS API Wrapper デプロイスクリプト
# non-blocking TTS対応の高性能音声合成APIをCloud Runにデプロイ

set -e

# 設定
PROJECT_ID="your-project-id"
SERVICE_NAME="voicevox-tts-api"
REGION="asia-northeast1"
MEMORY="2Gi"
CPU="2"
MAX_INSTANCES="10"
MIN_INSTANCES="1"
CONCURRENCY="50"  # non-blocking対応で高い並行性

echo "🚀 VOICEVOX TTS API Wrapper をCloud Runにデプロイします..."

# プロジェクト設定
gcloud config set project $PROJECT_ID

# Cloud Buildでイメージをビルド
echo "📦 Dockerイメージをビルドしています..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME -f Dockerfile.tts-api .

# Cloud Runにデプロイ
echo "🌐 Cloud Runサービスをデプロイしています..."
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory $MEMORY \
  --cpu $CPU \
  --max-instances $MAX_INSTANCES \
  --min-instances $MIN_INSTANCES \
  --concurrency $CONCURRENCY \
  --timeout 60s \
  --set-env-vars "VOICEVOX_HOST=https://voicevox-engine-198779252752.asia-northeast1.run.app" \
  --execution-environment gen2

# サービスURL取得
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format 'value(status.url)')

echo "✅ デプロイ完了!"
echo "🔗 TTS API URL: $SERVICE_URL"
echo ""
echo "📋 使用方法:"
echo "POST $SERVICE_URL/tts"
echo '{"text": "こんにちは", "speaker": 3}'
echo ""
echo "🔥 ウォームアップ:"
echo "POST $SERVICE_URL/warmup"
echo ""
echo "💊 ヘルスチェック:"
echo "GET $SERVICE_URL/health"