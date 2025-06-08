# スケーラブルマッチングシステム設計書

## アーキテクチャ概要

### 従来のシステムの問題点
- Firebaseクライアントサイドでのマッチング処理
- 同時接続数の制限
- レーティング計算の非効率性
- グローバルスケールでの遅延

### 新しいアーキテクチャ
```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│Flutter App  │─────▶│  Cloud Run   │─────▶│Cloud Tasks  │
│             │      │   (API)      │      │  (Queue)    │
└─────────────┘      └──────────────┘      └─────────────┘
       │                                           │
       │                                           ▼
       │                                    ┌─────────────┐
       │                                    │  Workers    │
       │                                    │ (Matching)  │
       │                                    └─────────────┘
       │                                           │
       ▼                                           ▼
┌─────────────┐                            ┌─────────────┐
│  Firestore  │◀───────────────────────────│  Firestore  │
│ (Listener)  │                            │  (Update)   │
└─────────────┘                            └─────────────┘
```

## 主要コンポーネント

### 1. Cloud Run API サービス
- **責務**: APIエンドポイント提供、認証、バリデーション
- **スケーリング**: 自動（0-10インスタンス）
- **メモリ**: 512MB
- **CPU**: 1vCPU
- **同時実行数**: 100リクエスト/インスタンス

### 2. Cloud Tasks キュー
- **責務**: 非同期マッチング処理のキューイング
- **スループット**: 100リクエスト/秒
- **同時実行**: 1000タスク
- **リトライ**: 最大3回、指数バックオフ

### 3. マッチングアルゴリズム
```python
# 優先順位
1. レーティング差（±200ポイント）
2. 待機時間（長い方を優先）
3. 地域の近さ
4. 共通の興味
```

## スケーリング戦略

### 水平スケーリング
- **Cloud Run**: CPU使用率80%で自動スケール
- **最小インスタンス**: 1（コールドスタート対策）
- **最大インスタンス**: 10（コスト制御）

### 地域分散
```yaml
regions:
  - asia-northeast1  # 東京
  - us-central1      # アメリカ
  - europe-west1     # ヨーロッパ
```

### キャッシング戦略
- Redis/Memorystore for Redis使用
- アクティブユーザーのレーティングキャッシュ
- TTL: 5分

## パフォーマンス最適化

### 1. バッチ処理
- 複数のマッチングリクエストを一括処理
- 10秒ごとにバッチ実行

### 2. インデックス最適化
```javascript
// Firestore複合インデックス
matchRequests: {
  indexes: [
    ['status', 'userRating', 'createdAt'],
    ['status', 'region', 'userRating'],
    ['userId', 'status', 'createdAt']
  ]
}
```

### 3. コネクションプーリング
- Firestore: 最大10コネクション
- Cloud Tasks: Keep-Alive有効

## モニタリング・アラート

### メトリクス
- マッチング成功率
- 平均待機時間
- キュー深度
- エラー率

### アラート条件
- マッチング成功率 < 80%
- 平均待機時間 > 60秒
- エラー率 > 5%

## セキュリティ

### 認証・認可
- Firebase Authentication IDトークン検証
- Cloud Run IAMポリシー
- VPC Service Controls（オプション）

### レート制限
- ユーザーごと: 10リクエスト/分
- IP単位: 100リクエスト/分

## コスト最適化

### 予想コスト（月間）
```
Cloud Run: $50-200（トラフィック依存）
Cloud Tasks: $40（100万タスク）
Firestore: $100-300（読み書き量依存）
合計: $190-540/月
```

### コスト削減策
1. アイドル時のスケールダウン
2. リージョン別料金最適化
3. Firestoreバッチ書き込み

## デプロイ手順

### 1. 環境準備
```bash
# GCPプロジェクト設定
export PROJECT_ID=your-project-id
gcloud config set project $PROJECT_ID

# APIを有効化
gcloud services enable run.googleapis.com
gcloud services enable cloudtasks.googleapis.com
gcloud services enable firestore.googleapis.com
```

### 2. Terraformでインフラ構築
```bash
cd cloud_run/terraform
terraform init
terraform plan -var="project_id=$PROJECT_ID"
terraform apply -var="project_id=$PROJECT_ID"
```

### 3. アプリケーションデプロイ
```bash
cd ../
./deploy.sh
```

## トラブルシューティング

### よくある問題

1. **コールドスタート遅延**
   - 解決: 最小インスタンス数を1に設定

2. **マッチング遅延**
   - 解決: インデックス最適化、キャッシュ活用

3. **コスト超過**
   - 解決: 自動スケーリング上限設定、使用量モニタリング

## 将来の拡張

### Phase 2
- 機械学習によるマッチング最適化
- リアルタイムレコメンデーション
- グローバルレプリケーション

### Phase 3
- GraphQLサブスクリプション
- WebSocketサポート
- エッジコンピューティング統合