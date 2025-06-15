#!/bin/bash

# VOICEVOX Engine Cloud Run デプロイスクリプト

set -e

# 設定
PROJECT_ID="myproject-c8034"  # あなたのGCPプロジェクトIDに変更
SERVICE_NAME="voicevox-engine"
REGION="asia-northeast1"  # 東京リージョン
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "VOICEVOX Engine をCloud Runにデプロイします..."
echo "プロジェクトID: ${PROJECT_ID}"
echo "サービス名: ${SERVICE_NAME}"
echo "リージョン: ${REGION}"

# Docker buildxを設定（初回のみ必要）
if ! docker buildx ls | grep -q mybuilder; then
  echo "Docker buildxを設定しています..."
  docker buildx create --name mybuilder --use
  docker buildx inspect --bootstrap
fi

# Dockerイメージをビルド（amd64/linux用にクロスプラットフォームビルド）
echo "Dockerイメージをビルドしています（amd64/linux用）..."
docker buildx build --platform linux/amd64 -t ${IMAGE_NAME} --push .

# Cloud Runにデプロイ
echo "Cloud Runにデプロイしています..."
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated \
  --memory 4Gi \
  --cpu 2 \
  --concurrency 10 \
  --timeout 900 \
  --set-env-vars="CORS_ALLOW_ORIGIN=*" \
  --execution-environment gen2

# デプロイ完了メッセージ
echo "デプロイが完了しました！"
echo "VOICEVOX Engine URL:"
gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)'

echo ""
echo "使用方法:"
echo "1. 上記のURLをFlutterアプリのVoiceVoxServiceの_defaultHostに設定してください"
echo "2. アプリでVOICEVOX機能をテストしてください"