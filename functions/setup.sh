#!/bin/bash

# TalkOne 通報機能セットアップスクリプト（GCP純正版）

echo "🚀 TalkOne 通報機能セットアップを開始します..."

# プロジェクト情報の確認
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ Google Cloud プロジェクトが設定されていません"
    echo "   gcloud config set project YOUR_PROJECT_ID を実行してください"
    exit 1
fi

echo "📋 プロジェクト ID: $PROJECT_ID"

# 必要なAPIの有効化
echo "🛠️  必要なAPIを有効化中..."
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable firebase.googleapis.com
gcloud services enable monitoring.googleapis.com

echo "✅ APIの有効化が完了しました"

# 依存関係のインストール
echo "📦 依存関係をインストール中..."
npm install

if [ $? -eq 0 ]; then
    echo "✅ 依存関係をインストールしました"
else
    echo "❌ 依存関係のインストールに失敗しました"
    exit 1
fi

# TypeScript ビルド
echo "🔨 TypeScript ビルド中..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ ビルドが完了しました"
else
    echo "❌ ビルドに失敗しました"
    exit 1
fi

echo ""
echo "🎉 セットアップが完了しました！"
echo ""
echo "📋 次のステップ:"
echo "   1. firebase deploy --only functions を実行"
echo "   2. Cloud Logging コンソールで通報アラートを確認"
echo "   3. 必要に応じて Cloud Monitoring アラートを設定"
echo ""
echo "📊 管理者ダッシュボード:"
echo "   - Cloud Logging: https://console.cloud.google.com/logs?project=$PROJECT_ID"
echo "   - フィルター: labels.report_type=\"user_report\""
echo "   - Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID"
echo ""
echo "🔗 参考リンク:"
echo "   - Cloud Logging: https://cloud.google.com/logging/docs"
echo "   - Cloud Monitoring: https://cloud.google.com/monitoring/docs"
echo "   - Firebase Functions: https://firebase.google.com/docs/functions"