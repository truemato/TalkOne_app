# Agoraトークンエラーの修正方法

## 問題
```
Agora エラー: ErrorCodeType.errInvalidToken
```

## 原因
現在のApp ID `5633ebf2d65c415581178e25fb64d859` はApp Certificate（証明書）が有効になっているため、トークンが必要です。

## 解決方法

### 方法1: 新しいテスト用App IDを作成（推奨）

1. **Agora Console** (https://console.agora.io/) にアクセス
2. **新規プロジェクト作成**
   - プロジェクト名: `TalkOne-Test`
   - 認証モード: **`Testing mode: APP ID`** を選択（重要！）
3. **App IDをコピー**
4. `agora_config.dart`を更新

### 方法2: 現在のプロジェクトでApp Certificateを無効化

⚠️ **注意**: 他の人も使用している可能性があるため非推奨

## 手順（方法1）

### 1. Agora Consoleでの作業
```
1. https://console.agora.io/ → ログイン
2. 「Create Project」をクリック
3. Project name: TalkOne-Test
4. 「Use case」: Voice Call
5. 「Authentication mechanism」: Testing mode: APP ID を選択
6. 「Create」をクリック
7. 生成されたApp IDをコピー
```

### 2. コード更新
agora_config.dartのApp IDを新しいものに置き換え：

```dart
static const String appId = "YOUR_NEW_APP_ID_HERE";
```

### 3. テスト
- アプリを再起動
- 音声通話をテスト
- "User joined"メッセージが表示されるか確認

## 一時的な回避策

現在のエラーが続く場合は、再度シミュレーションモードに戻すことも可能：

```dart
// app_config.dart
static const bool useAgoraSimulation = true;
```

## 本番環境用のトークンサーバー

本番環境では必ずトークンサーバーを実装してください：

1. Cloud Functions for Firebaseでトークン生成エンドポイントを作成
2. App Certificate使用モードに変更
3. クライアントアプリからトークンを取得して音声通話開始

## 現在の状況確認

実際のApp IDが必要な場合は、以下を教えてください：
1. 新しいAgora App IDを作成できますか？
2. または、一旦シミュレーションモードに戻しますか？