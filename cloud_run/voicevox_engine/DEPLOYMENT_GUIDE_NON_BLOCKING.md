# VOICEVOX Engine Non-blocking TTS デプロイガイド

## 概要

このガイドでは、高性能なnon-blocking TTS（Text-to-Speech）システムをCloud Runにデプロイする方法を説明します。

## アーキテクチャ

1. **VOICEVOX Engine** - non-blocking TTS設定で複数プロセス起動
2. **TTS API Wrapper** - 一発変換APIとエンジンウォームアップ機能
3. **Flutter App** - マッチング時の自動ウォームアップ統合

## デプロイ手順

### 1. VOICEVOX Engine (non-blocking)

```bash
# 既存のVOICEVOX Engineを更新
cd cloud_run/voicevox_engine

# non-blocking設定でデプロイ
./deploy.sh
```

**設定内容:**
- `--enable_cancellable_synthesis`: non-blocking TTS有効化
- `--init_processes 5`: 5つのTTSプロセス同時起動
- `POST /cancellable_synthesis`エンドポイント使用

### 2. TTS API Wrapper

```bash
# TTS API Wrapperをデプロイ
./deploy-tts-api.sh
```

**特徴:**
- テキストから音声への一発変換API
- エンジンウォームアップ機能
- 高い並行性（50リクエスト同時処理）

### 3. アプリケーション統合

Flutter側でマッチング時のウォームアップが自動実行されます：

```dart
// マッチング成立時
await _warmupService.warmupEnginesOnMatching();
```

## API仕様

### POST /tts (一発音声変換)

```bash
curl -X POST "https://voicevox-tts-api-xxx.run.app/tts" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "こんにちは、ずんだもんです",
    "speaker": 3,
    "speed": 1.0,
    "pitch": 0.0,
    "intonation": 1.0,
    "volume": 1.0
  }' \
  --output speech.wav
```

### POST /warmup (エンジンウォームアップ)

```bash
curl -X POST "https://voicevox-tts-api-xxx.run.app/warmup"
```

### GET /health (ヘルスチェック)

```bash
curl "https://voicevox-tts-api-xxx.run.app/health"
```

## パフォーマンス特性

### Non-blocking の利点

1. **並列処理**: 複数の音声合成リクエストを同時処理
2. **低レイテンシ**: 前のクエリ完了を待たずに処理開始
3. **高スループット**: 5つのTTSプロセスで処理能力向上

### コールドスタート対策

1. **マッチング時ウォームアップ**: 2つのエンジンを事前起動
2. **最小インスタンス**: Cloud Runで1インスタンス常時起動
3. **一発変換API**: クエリ作成→合成の2段階を1段階に短縮

## モニタリング

### Cloud Runメトリクス

- **同時リクエスト数**: 最大50（non-blocking対応）
- **レスポンス時間**: 平均2-5秒（ウォームアップ済み）
- **スループット**: 1分間に100+リクエスト処理可能

### ログ確認

```bash
# TTS API Wrapper ログ
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=voicevox-tts-api" --limit 50

# VOICEVOX Engine ログ
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=voicevox-engine" --limit 50
```

## トラブルシューティング

### よくある問題

1. **音声合成タイムアウト**
   - Cloud Runのタイムアウト設定を60秒に設定済み
   - 長すぎるテキスト（140文字制限で回避）

2. **エンジンウォームアップ失敗**
   - ネットワーク接続確認
   - TTS APIサービスの起動状態確認

3. **高負荷時のパフォーマンス**
   - Cloud Runの最大インスタンス数調整
   - `--init_processes`の値調整

## 設定パラメータ

### VOICEVOX Engine

```bash
--enable_cancellable_synthesis  # non-blocking TTS有効
--init_processes 5              # 同時起動プロセス数
--host 0.0.0.0                 # すべてのIPからアクセス許可
--port 50021                    # ポート設定
--allow_origin "*"              # CORS設定
```

### TTS API Wrapper

```bash
--workers 4                     # Gunicornワーカー数
--threads 2                     # スレッド数
--timeout 60                    # タイムアウト
--worker-class aiohttp.GunicornWebWorker  # 非同期ワーカー
```

## セキュリティ

- Cloud RunのIAM設定で適切なアクセス制御
- VPCコネクタでプライベートネットワーク通信（オプション）
- API Keyによるアクセス制限（必要に応じて）

## コスト最適化

1. **最小インスタンス**: 1台で待機
2. **自動スケーリング**: 負荷に応じて最大10台まで拡張
3. **リソース効率**: CPU 2コア、メモリ2GBで最適化

このnon-blocking TTS設定により、TalkOneアプリでの音声合成性能が大幅に向上します。