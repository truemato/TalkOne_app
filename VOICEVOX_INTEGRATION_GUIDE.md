# TalkOne VOICEVOX統合ガイド

TalkOneアプリにVOICEVOX音声合成機能を統合しました。このガイドでは、実装内容と使用方法について説明します。

## 実装内容

### 1. 新規追加ファイル

#### サービスクラス
- `lib/services/voicevox_service.dart` - VOICEVOX音声合成サービス
- `lib/services/ai_voice_chat_service_voicevox.dart` - VOICEVOX統合AI音声チャット

#### UI画面
- `lib/screens/voicevox_test_screen.dart` - VOICEVOX機能テスト画面

#### クラウドデプロイ設定
- `cloud_run/voicevox_engine/Dockerfile` - VOICEVOX Engine用Dockerfile
- `cloud_run/voicevox_engine/deploy.sh` - Cloud Runデプロイスクリプト
- `cloud_run/voicevox_engine/README.md` - デプロイガイド

### 2. 更新ファイル

#### 依存関係
- `pubspec.yaml` - `audioplayers: ^6.4.0` を追加

#### UI
- `lib/screens/home_screen.dart` - VOICEVOXテスト画面へのナビゲーション追加

## 機能概要

### VoiceVoxService
- VOICEVOX Engineとの通信
- 音声合成パラメータの調整（話速、音高、抑揚、音量）
- 話者（キャラクター）の選択
- ローカル/クラウドエンジンの切り替え

### PersonalityVoiceMapping
- AI人格に応じた音声設定の自動選択
- 5種類の人格に対応した話者とパラメータのマッピング

### AIVoiceChatServiceVoiceVox
- 既存のAI音声チャット機能の拡張
- VoiceVoxとFlutterTTSの切り替え対応
- エンジン接続失敗時の自動フォールバック

## セットアップ手順

### 1. 依存関係のインストール

```bash
cd /Users/hundlename/_dont_think_write_Talkone/TalkOne
flutter pub get
```

### 2. ローカル開発環境

#### VOICEVOX Engineの起動（Docker）
```bash
docker run --rm -d --name voicevox-engine -p 127.0.0.1:50021:50021 voicevox/voicevox_engine:cpu-latest
```

#### 接続確認
```bash
curl http://127.0.0.1:50021/version
```

### 3. クラウド本番環境

#### Google Cloud Runへのデプロイ
```bash
cd cloud_run/voicevox_engine
# deploy.shのPROJECT_IDを実際の値に変更
./deploy.sh
```

#### アプリ設定の更新
デプロイ後のURLを`lib/services/voicevox_service.dart`の`_defaultHost`に設定：

```dart
static const String _defaultHost = "https://your-voicevox-service-url.run.app";
```

## 使用方法

### 1. 基本的な音声合成

```dart
final voiceVoxService = VoiceVoxService();

// エンジンの可用性チェック
final available = await voiceVoxService.isEngineAvailable();

if (available) {
  // 音声合成実行
  await voiceVoxService.speak("こんにちは、VOICEVOXです。");
}
```

### 2. 話者とパラメータの設定

```dart
// 話者の選択
voiceVoxService.setSpeaker(1); // ずんだもん

// 音声パラメータの調整
voiceVoxService.setVoiceParameters(
  speed: 1.2,    // 話速（0.5-2.0）
  pitch: 0.1,    // 音高（-0.15-0.15）
  intonation: 1.1, // 抑揚（0.0-2.0）
  volume: 1.0,   // 音量（0.0-2.0）
);
```

### 3. AI音声チャットでの使用

```dart
final aiVoiceChat = AIVoiceChatServiceVoiceVox(
  speech: SpeechToText(),
  tts: FlutterTts(),
  useVoiceVox: true, // VOICEVOXを使用
);

// 初期化
await aiVoiceChat.initialize();

// 音声認識開始
await aiVoiceChat.startListening();
```

### 4. 人格に応じた音声設定

```dart
// 人格IDに応じた音声設定を自動適用
final personalityId = 1; // 親切な人格
final voiceConfig = PersonalityVoiceMapping.getVoiceConfig(personalityId);

if (voiceConfig != null) {
  voiceVoxService.setSpeaker(voiceConfig.speakerId);
  voiceVoxService.setVoiceParameters(
    speed: voiceConfig.speed,
    pitch: voiceConfig.pitch,
    intonation: voiceConfig.intonation,
    volume: voiceConfig.volume,
  );
}
```

## テスト方法

### 1. VOICEVOXテスト画面
- ホーム画面の「VOICEVOXテスト」ボタンをタップ
- エンジン接続状態の確認
- 話者選択とパラメータ調整
- テキスト入力による音声合成テスト

### 2. AI練習モードでのテスト
- ホーム画面の「AI練習モード」をタップ
- VOICEVOX音声によるAI応答の確認

## トラブルシューティング

### エンジン接続エラー
1. Docker/クラウドサービスの起動状態確認
2. ファイアウォール設定の確認
3. CORS設定の確認（Webアプリの場合）

### 音声再生エラー
1. `audioplayers`パッケージの権限確認
2. デバイスの音量設定確認
3. エラーログの確認

### パフォーマンス問題
1. CPU/GPU版の選択最適化
2. 同時リクエスト数の制限
3. キャッシュ機能の実装検討

## 今後の拡張予定

### 機能追加
- [ ] 音声ファイルの保存/読み込み
- [ ] カスタム話者の追加
- [ ] 感情表現の強化
- [ ] 音声効果の追加

### パフォーマンス最適化
- [ ] 音声合成結果のキャッシュ
- [ ] ストリーミング再生対応
- [ ] GPU加速の活用

### UI/UX改善
- [ ] リアルタイム音声パラメータ調整
- [ ] 話者プレビュー機能
- [ ] 音声品質設定

## 技術仕様

### 対応プラットフォーム
- iOS/Android (audioplayers経由)
- Web (Web Audio API経由、CORS制限あり)
- macOS/Windows/Linux (audioplayers経由)

### 音声形式
- 出力: WAV形式
- サンプリングレート: 24kHz
- ビット深度: 16bit

### 話者対応
- VOICEVOX標準話者すべて
- 追加音声ライブラリ対応可能

## ライセンス・利用規約

VOICEVOX Engineの利用規約に従って使用してください：
- [VOICEVOX利用規約](https://voicevox.hiroshiba.jp/term/)
- 音声合成結果の商用利用制限に注意
- キャラクター画像の使用制限に注意