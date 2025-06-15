#!/bin/bash

# VOICEVOX Engine Cloud Run デプロイスクリプト（Cloud Build使用版）

set -e

# 設定
PROJECT_ID="myproject-c8034"
SERVICE_NAME="voicevox-engine"
REGION="asia-northeast1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "VOICEVOX Engine をCloud Runにデプロイします（Cloud Build使用）..."
echo "プロジェクトID: ${PROJECT_ID}"
echo "サービス名: ${SERVICE_NAME}"
echo "リージョン: ${REGION}"

# Cloud Buildを使用してビルド
echo "Cloud Buildでイメージをビルドしています..."
gcloud builds submit --tag ${IMAGE_NAME} .

# Cloud Runにデプロイ
echo "Cloud Runにデプロイしています..."
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --concurrency 80 \
  --timeout 300 \
  --port 50021 \
  --set-env-vars="CORS_ALLOW_ORIGIN=*"

# デプロイ完了メッセージ
echo "デプロイが完了しました！"
echo "VOICEVOX Engine URL:"
gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)'

echo ""
echo "使用方法:"
echo "1. 上記のURLをFlutterアプリのVoiceVoxServiceの_defaultHostに設定してください"
echo "2. アプリでVOICEVOX機能をテストしてください"