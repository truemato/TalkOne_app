# Apple Developer セットアップガイド

## Bundle ID設定
- **Bundle ID**: `com.truemato.TalkOne`
- **Description**: `1 vs 1 Talk App`
- **Team ID**: `658363YSD7`

### 代替Bundle ID候補
- `com.truemato.TalkOne`
- `com.truemato.talkone`
- `jp.truemato.TalkOne`
- `com.658363YSD7.TalkOne`

## 必要なCapabilities

### 必須項目（チェック必要）
1. **Push Notifications** ✓
   - マッチング成功通知
   - 通話リクエスト通知

2. **Sign In with Apple** ✓  
   - Apple認証機能
   - プライバシー重視ユーザー向け

3. **iCloud** ✓
   - ユーザープロフィール同期
   - 会話履歴保存

### 推奨項目
4. **Game Center**
   - レーティングシステム
   - ランキング機能

5. **In-App Purchase**
   - プレミアム機能
   - 将来の収益化

6. **Background Modes** (後で追加)
   - 通話継続
   - 音声処理継続

## Sign in with Apple設定

### Server-to-Server Notification Endpoint
現在の開発段階では、以下のいずれかを使用：

#### 開発環境
- 空欄のまま進める（オプショナル）
- または: `https://api.truemato.com/apple/notifications`（将来実装予定）

#### 本番環境（将来実装時）
```
https://api.truemato.com/apple/notifications
```

### 通知内容
- ユーザーのメール転送設定変更
- アプリアカウント削除
- Apple ID完全削除

## 設定完了後の作業

1. **Provisioning Profile作成**
2. **Development Certificate設定**
3. **Xcode Project設定更新**
4. **Info.plist権限追加**

## 注意事項
- Bundle IDは後から変更困難
- 本番リリース前にApp Store Connect設定も必要
- TestFlight配布にはApp Store Connect登録が必要