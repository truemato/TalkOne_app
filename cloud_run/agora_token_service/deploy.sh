#!/bin/bash

# Agora Token Service Cloud Run デプロイスクリプト

# 設定変数
PROJECT_ID="your-gcp-project-id"
SERVICE_NAME="agora-token-service"
REGION="asia-northeast1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Agoraの認証情報（環境変数から取得またはここで設定）
AGORA_APP_ID="${AGORA_APP_ID:-4067eac9200f4aebb0fcf1b190eabd7d}"
AGORA_APP_CERTIFICATE="${AGORA_APP_CERTIFICATE:-YOUR_APP_CERTIFICATE_HERE}"

echo "Agora Token Serviceをデプロイします..."
echo "プロジェクトID: $PROJECT_ID"
echo "サービス名: $SERVICE_NAME"
echo "リージョン: $REGION"

# Dockerイメージをビルド
echo "Dockerイメージをビルド中..."
docker build -t $IMAGE_NAME .

# イメージをGoogle Container Registryにプッシュ
echo "イメージをGCRにプッシュ中..."
docker push $IMAGE_NAME

# Cloud Runにデプロイ
echo "Cloud Runにデプロイ中..."
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --set-env-vars AGORA_APP_ID=$AGORA_APP_ID,AGORA_APP_CERTIFICATE=$AGORA_APP_CERTIFICATE \
    --memory 512Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 10 \
    --concurrency 100 \
    --timeout 300

if [ $? -eq 0 ]; then
    echo "デプロイが完了しました！"
    echo "サービスURL:"
    gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)'
else
    echo "デプロイに失敗しました。"
    exit 1
fi