# Firebase データ構造 - TalkOne

TalkOneアプリで会話データがFirestore上に保存される詳細な構造について説明します。

## 📊 **Firestoreコレクション構造**

### 1. `/conversation_sessions` - 会話セッション
会話全体を管理するメインコレクション

```javascript
/conversation_sessions/{sessionDocId}
{
  sessionId: "1641234567890_abc12345",     // ユニークセッションID
  participants: ["userUID1", "AI-3"],      // 参加者（ユーザーUID、AI識別子）
  type: "ai",                              // 会話タイプ (voice/video/ai)
  isAIPartner: true,                       // AI相手かどうか
  startTime: Timestamp,                    // 会話開始時刻
  endTime: Timestamp | null,               // 会話終了時刻
  status: "completed",                     // セッション状態 (active/completed/aborted/error)
  totalDuration: 180,                      // 総会話時間（秒）
  messageCount: 25,                        // メッセージ総数
  endReason: "timeLimit",                  // 終了理由 (timeLimit/userLeft/partnerLeft/networkError/systemError)
  ratings: {                               // 評価データ
    "userUID1": 4,
    "AI-3": 5
  },
  createdAt: Timestamp,                    // 作成日時
  updatedAt: Timestamp                     // 更新日時
}
```

### 2. `/conversation_messages` - 会話メッセージ
各発言を記録するコレクション

```javascript
/conversation_messages/{messageDocId}
{
  sessionId: "1641234567890_abc12345",     // 対応するセッションID
  speakerId: "userUID1",                   // 発言者ID（ユーザーUID or "AI"）
  transcribedText: "こんにちは、元気ですか？", // STTで変換された文字
  confidence: 0.85,                        // STT信頼度 (0.0-1.0)
  timestamp: Timestamp,                    // 発言時刻
  originalAudioUrl: "gs://bucket/audio/...", // 元音声ファイルURL（オプション）
  isAIGenerated: false,                    // AI生成かどうか
  aiPersonalityId: null,                   // AI人格ID（AI発言の場合）
  voiceCharacter: null,                    // 音声キャラクター（AI発言の場合）
  metadata: {                              // 追加メタデータ
    source: "user_speech",
    language: "ja_JP",
    personalityId: 3,
    model: "gemini-2.5-flash-preview-05-20"
  },
  createdAt: Timestamp                     // 作成日時
}
```

### 3. `/users/{userUID}/amenity_history` - アメニティレベル履歴
ユーザーのアメニティレベル変更履歴（サブコレクション）

```javascript
/users/{userUID}/amenity_history/{historyDocId}
{
  oldLevel: "silver",                      // 変更前レベル
  newLevel: "gold",                        // 変更後レベル
  timestamp: Timestamp                     // 変更時刻
}
```

### 4. 既存の `/users` コレクション拡張
既存のユーザーデータに会話統計を追加

```javascript
/users/{userUID}
{
  // 既存フィールド
  rating: 350,
  totalEvaluations: 15,
  
  // 新規追加フィールド
  conversationStats: {
    totalSessions: 25,                     // 総会話回数
    totalDurationSeconds: 4500,            // 総会話時間（秒）
    aiSessions: 8,                         // AI会話回数
    humanSessions: 17,                     // 人間との会話回数
    averageRating: 4.2,                    // 平均評価
    lastConversationAt: Timestamp          // 最終会話日時
  }
}
```

## 🔍 **データクエリパターン**

### ユーザーの会話履歴取得
```dart
// 特定ユーザーの直近20件の会話を取得
Query query = FirebaseFirestore.instance
    .collection('conversation_sessions')
    .where('participants', arrayContains: userUID)
    .orderBy('startTime', descending: true)
    .limit(20);
```

### AI学習用データ取得
```dart
// 高信頼度のSTTデータを1000件取得
Query query = FirebaseFirestore.instance
    .collection('conversation_messages')
    .where('confidence', isGreaterThanOrEqualTo: 0.8)
    .orderBy('confidence', descending: true)
    .orderBy('createdAt', descending: true)
    .limit(1000);
```

### 特定セッションの全メッセージ取得
```dart
// セッションIDに基づく会話内容の取得
Query query = FirebaseFirestore.instance
    .collection('conversation_messages')
    .where('sessionId', isEqualTo: sessionId)
    .orderBy('timestamp');
```

## 🔒 **Security Rules 設定例**

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 会話セッション：参加者のみ読み取り可能
    match /conversation_sessions/{sessionId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
    }
    
    // 会話メッセージ：関連セッションの参加者のみアクセス可能
    match /conversation_messages/{messageId} {
      allow read, write: if request.auth != null && 
        isSessionParticipant(resource.data.sessionId, request.auth.uid);
    }
    
    // ユーザーデータ：本人のみアクセス可能
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // アメニティ履歴サブコレクション
      match /amenity_history/{historyId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // セッション参加者チェック関数
    function isSessionParticipant(sessionId, userId) {
      return get(/databases/$(database)/documents/conversation_sessions/$(sessionId))
        .data.participants.hasAny([userId]);
    }
  }
}
```

## 📈 **データ使用目的と活用方法**

### 1. AI機能向上
- **高信頼度STTデータ**: confidence >= 0.8 のデータでAI訓練
- **人格別会話パターン**: personalityId別の応答傾向分析
- **ユーザー満足度**: ratings データによる応答品質評価

### 2. ユーザー体験向上
- **会話履歴表示**: 過去の会話セッション一覧
- **統計情報**: 総会話時間、平均評価、使用頻度
- **パーソナライゼーション**: 過去の会話に基づく推奨機能

### 3. アプリ分析・改善
- **使用パターン分析**: 人気の人格、時間帯別使用状況
- **品質監視**: STT信頼度、セッション完了率
- **不正利用検知**: 異常な評価パターン、不適切な発言

## 🛡️ **プライバシー保護対策**

### 1. データ匿名化
- **ユーザーUID**: Firebase Authの匿名UID使用
- **個人情報なし**: 氏名、連絡先等の収集・保存なし
- **会話内容**: 統計・分析目的のみ使用

### 2. データ保持期間
- **アクティブユーザー**: 無期限保持
- **非アクティブユーザー**: 6ヶ月後自動削除検討
- **AI学習データ**: 集約後に個別記録削除

### 3. ユーザー制御
- **データ削除リクエスト**: ユーザーによる削除要求対応
- **データダウンロード**: 個人データのエクスポート機能
- **利用停止**: データ収集の無効化オプション

## 📊 **推定データサイズ**

### 月間アクティブユーザー1000人の場合
- **セッション数**: 約10,000セッション/月
- **メッセージ数**: 約250,000メッセージ/月
- **データサイズ**: 約50MB/月（テキストのみ）
- **音声データ**: 約500GB/月（3分間×44.1kHz×16bit）

### コスト最適化
- **音声データ**: Cloud Storage、生データは7日後削除
- **インデックス**: 必要最小限のフィールドのみ
- **TTL設定**: 古いデータの自動削除