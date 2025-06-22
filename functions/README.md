# TalkOne 通報機能 Cloud Functions

このディレクトリには、TalkOneアプリの通報機能を処理するCloud Functionsが含まれています。

## 機能概要

### 🚨 sendReportAlert
- Firestoreの `reports` コレクションに新しい通報が追加されると自動実行
- **Cloud Logging** に緊急アラート（ERROR レベル）を出力
- **adminNotifications** コレクションに通知レコードを追加
- **Console** に詳細な通報情報を表示（管理者確認用）
- 通報者・被通報者の詳細情報を含む包括的なレポートを生成

### 📊 updateReportStats  
- 毎日午前0時に実行されるスケジュール関数
- 前日の通報統計を集計して `reportStats` コレクションに保存

## セットアップ手順

### 1. GCP APIs の有効化

```bash
# 必要なAPIを有効化
gcloud services enable logging.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable firebase.googleapis.com
gcloud services enable monitoring.googleapis.com
```

### 2. 管理者通知システム

**通知先**: serveman520@gmail.com（設定済み）

**通知方法（3つの並行処理）**:
1. **Cloud Logging**: ERROR レベルでアラート出力
2. **Firestore**: `adminNotifications` コレクションに緊急通知追加
3. **Console**: 詳細な通報情報をコンソールログに出力

**通知内容**:
- 🚨 緊急度表示（高）
- 👤 通報者詳細情報（UID、ニックネーム、レーティング等）
- 🎯 被通報者詳細情報
- 📞 通話情報（Call ID、AIマッチ判定）
- 🔗 管理者向け直接リンク（Firebase Console、Cloud Logging）

### 3. 管理者確認方法

**Cloud Logging Console**:
```
https://console.cloud.google.com/logs?project=YOUR_PROJECT_ID
フィルター: labels.report_type="user_report"
```

**Firebase Console**:
```
https://console.firebase.google.com/project/YOUR_PROJECT_ID/firestore/data/~2FadminNotifications
```

### 4. 依存関係のインストールとビルド

```bash
cd functions
npm install
npm run build
```

### 5. Cloud Functions のデプロイ

```bash
# Firebase CLI でデプロイ
firebase deploy --only functions

# または gcloud CLI でデプロイ
gcloud functions deploy sendReportAlert --gen2 \
  --runtime nodejs20 \
  --trigger-event-filters="type=google.cloud.firestore.document.v1.created" \
  --trigger-event-filters="database=(default)" \
  --trigger-event-filters-path-pattern="documents/reports/{reportId}"
```

## Firestore データ構造

### reports コレクション

```typescript
{
  reporterUid: string;      // 通報者のUID
  reporterEmail: string;    // 通報者のメールアドレス
  reportedUid: string;      // 被通報者のUID
  callId: string;           // 通話ID
  reason: string;           // 通報理由
  detail?: string;          // 詳細（任意）
  isDummyMatch: boolean;    // AIマッチかどうか
  status: string;           // 'pending' | 'reviewed' | 'resolved'
  createdAt: Timestamp;     // 作成日時
  alertSent?: boolean;      // アラート送信完了フラグ
  alertSentAt?: Timestamp;  // アラート送信日時
  alertType?: string;       // 'cloud_logging'
  alertError?: string;      // アラート送信エラー
}
```

### reportStats コレクション

```typescript
{
  date: string;            // 'YYYY-MM-DD' 形式
  totalReports: number;    // その日の総通報件数
  pendingReports: number;  // 未処理の通報件数
  processedReports: number; // 処理済みの通報件数
  updatedAt: Timestamp;    // 更新日時
}
```

## 動作フロー

```
Flutter アプリ
    ↓ 通報ボタン押下
Firestore reports コレクション
    ↓ onCreate トリガー
sendReportMail 関数
    ↓ SendGrid API
管理者メールボックス
```

## セキュリティ考慮事項

- ✅ SendGrid API キーは Secret Manager で暗号化保存
- ✅ 通報データは Firestore Security Rules で保護
- ✅ Cloud Functions は認証済みユーザーからのみ実行
- ✅ 個人情報は最小限に抑制

## モニタリング

```bash
# Cloud Functions ログの確認
firebase functions:log

# または
gcloud functions logs read sendReportMail --limit 50

# エラー監視
gcloud logging read "resource.type=cloud_function AND severity>=ERROR" --limit 10
```

## 本番環境での注意点

1. **SendGrid 送信制限**: Free プランは 100通/日
2. **メールアドレス認証**: 送信元ドメインの DNS 設定が必要
3. **スパム対策**: 適切な SPF/DKIM/DMARC 設定
4. **コスト管理**: Cloud Functions の呼び出し回数監視

## トラブルシューティング

### メールが送信されない場合

1. Secret Manager のアクセス権限を確認
2. SendGrid API キーの有効性を確認
3. 送信元ドメインの認証状態を確認
4. Cloud Functions ログでエラー詳細を確認

### 大量通報時の対策

1. 送信レート制限の実装を検討
2. 優先度付きキューの導入
3. バッチ処理への移行を検討