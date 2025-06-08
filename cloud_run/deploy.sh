#!/bin/bash

# Cloud Run デプロイスクリプト

PROJECT_ID="your-project-id"
REGION="asia-northeast1"
SERVICE_NAME="matching-service"

# 1. Cloud Build でイメージをビルド
gcloud builds submit \
  --tag gcr.io/$PROJECT_ID/$SERVICE_NAME \
  ./matching_service

# 2. Cloud Run にデプロイ
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars PROJECT_ID=$PROJECT_ID,LOCATION=$REGION,QUEUE_NAME=matching-queue \
  --memory 512Mi \
  --cpu 1 \
  --concurrency 100 \
  --max-instances 10

# 3. Cloud Tasks キューを作成
gcloud tasks queues create matching-queue \
  --location=$REGION \
  --max-dispatches-per-second=100 \
  --max-concurrent-dispatches=1000 \
  --max-attempts=3 \
  --min-backoff=10s \
  --max-backoff=300s

echo "デプロイ完了！"