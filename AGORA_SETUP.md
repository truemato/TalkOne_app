# Agora 音声通話設定ガイド

## 🎯 現在の設定状況

### App ID
- **App ID**: `5633ebf2d65c415581178e25fb64d859`
- **ステータス**: 設定済み

## 🔧 Agora Console 設定手順

### 1. Agora Console アクセス
1. https://console.agora.io/ にアクセス
2. アカウントにログイン

### 2. プロジェクト設定
1. **Projects** → 該当プロジェクトを選択
2. **Basic Information** で App ID を確認

### 3. 認証設定（重要）
1. **Authentication** タブをクリック
2. **Testing mode** を選択（開発用）
3. **App Certificate** を **Disable** に設定

### 4. 権限設定
1. **Usage** タブで使用量を確認
2. **Voice Call** が有効になっていることを確認

## 📱 iOS設定

### 必要な権限（既に設定済み）
- マイク使用許可: ✅
- ネットワーク接続: ✅

## 🧪 テスト手順

### 1. 単一デバイステスト
1. アプリを起動
2. 「通話相手を探す」をタップ
3. 10秒待ってダミーマッチング
4. 音声通話画面でAgora接続確認

### 2. 2台デバイステスト
1. 同じアプリを2台にインストール
2. 両方で同時に「通話相手を探す」をタップ
3. マッチング成功後、実際の音声通話開始

## 🔍 トラブルシューティング

### よくあるエラー

1. **`errInvalidToken`**
   - Agora Consoleで **Testing mode** に設定
   - App Certificate を無効化

2. **`errInvalidAppId`**
   - App IDが正しく設定されているか確認
   - タイポがないか確認

3. **マイク権限エラー**
   - iOS設定 → プライバシー → マイクで権限確認
   - アプリを削除して再インストール

4. **接続エラー**
   - ネットワーク接続確認
   - Agoraサービス状況確認

## 📊 現在の実装状況

- ✅ Agora SDK統合
- ✅ 基本的な音声通話機能
- ✅ マッチングシステム
- ✅ 3分タイマー
- ✅ ミュート機能
- ✅ 通話終了処理

## 🚀 次のステップ

1. Agora Console設定完了
2. 実機での音声通話テスト
3. 音声品質調整
4. 本番環境用トークン認証実装

## 📞 サポート

- Agora公式ドキュメント: https://docs.agora.io/
- Agora Community: https://community.agora.io/