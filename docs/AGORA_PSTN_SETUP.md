# Agora PSTN/SIP 音声通話設定ガイド

## 現在の実装状況

### ✅ 完了済み（RTC有料プラン）
- トークンベース認証
- 通話時間トラッキング
- 課金計算（$0.99/1000分）
- Cloud Runでのトークンサービス

### 🔄 PSTN統合が必要な場合

## 1. Agora PSTN機能の有効化

### Agora Consoleでの設定
1. [Agora Console](https://console.agora.io/)にログイン
2. プロジェクトで「Cloud Recording」と「PSTN」を有効化
3. SIP設定を構成

## 2. 必要な追加実装

### 電話番号取得サービス
```dart
// lib/services/agora_pstn_service.dart
class AgoraPSTNService {
  // 電話番号への発信
  Future<String?> dialPhoneNumber({
    required String phoneNumber,
    required String callerNumber,
  }) async {
    // PSTN Gateway APIを呼び出し
  }
  
  // 着信の受付
  Future<void> acceptIncomingCall(String callId) async {
    // 着信処理
  }
}
```

### Cloud Run追加エンドポイント
```python
@app.route('/agora/pstn/dial', methods=['POST'])
def dial_pstn():
    """電話番号への発信"""
    data = request.json
    phone_number = data.get('phone_number')
    
    # Agora PSTN APIを使用
    # 通話セッションを開始
    
    return jsonify({
        'success': True,
        'session_id': session_id,
        'sip_uri': sip_uri
    })
```

## 3. 料金体系の違い

### RTC（現在の実装）
- **音声のみ**: $0.99/1000分
- **ビデオ付き**: $3.99/1000分

### PSTN/SIP
- **日本国内**: 約¥3-5/分
- **国際通話**: 地域により変動
- **着信**: 約¥2/分

## 4. 実装の選択

### 現在のRTC実装を使用する場合（推奨）
- インターネット経由の高品質音声
- 低コスト
- 既に実装完了

### PSTN統合が必要な場合
- 電話番号への発信が必要
- より高い信頼性が必要
- 追加実装が必要

## 推奨事項

現在の実装（RTCトークン認証）で十分な場合が多いです：
- ✅ 既に有料プラン対応
- ✅ 高品質な音声通話
- ✅ 課金トラッキング実装済み

PSTNは以下の場合のみ必要：
- 一般電話への発信
- 電話番号での着信
- 規制要件がある場合