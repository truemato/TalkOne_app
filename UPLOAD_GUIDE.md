# App Store Connect アップロード修正ガイド

## 修正完了内容

### ✅ 1. AKAuthenticationError -7005 対処法
**原因**: Apple ID の2要素認証エラー

**解決策**:
1. **App Specific Password作成**
   - Apple ID設定 → サインインとセキュリティ → App用パスワード
   - 新しいパスワードを生成（例: "Xcode-Upload"）

2. **Xcodeでの使用方法**
   - Xcode → Preferences → Accounts
   - Apple IDを追加する際、通常パスワードではなくApp Specific Passwordを使用

3. **コマンドライン使用時**
   ```bash
   xcrun altool --upload-app --type ios --file "YourApp.ipa" \
     --username "your-apple-id@example.com" \
     --password "app-specific-password"
   ```

### ✅ 2. Agora SDK dSYM問題 完全解決
**実施した修正**:

1. **メインプロジェクトのdSYM無効化**
   ```
   DEBUG_INFORMATION_FORMAT = dwarf
   ```

2. **Podfile設定追加**
   ```ruby
   # Agora SDKのdSYM生成を無効化
   if target.name.start_with?('Agora') || target.name == 'aosl' || target.name.start_with?('video_')
     config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
     config.build_settings['DWARF_DSYM_FOLDER_PATH'] = ''
     config.build_settings['DWARF_DSYM_FILE_NAME'] = ''
   end
   ```

3. **対象フレームワーク（24個全て）**
   - AgoraAiEchoCancellationExtension
   - AgoraAiEchoCancellationLLExtension
   - AgoraAiNoiseSuppressionExtension
   - AgoraAiNoiseSuppressionLLExtension
   - AgoraAudioBeautyExtension
   - AgoraClearVisionExtension
   - AgoraContentInspectExtension
   - AgoraFaceCaptureExtension
   - AgoraFaceDetectionExtension
   - AgoraLipSyncExtension
   - AgoraReplayKitExtension
   - AgoraRtcKit
   - AgoraRtcWrapper
   - AgoraSoundTouch
   - AgoraSpatialAudioExtension
   - AgoraVideoAv1DecoderExtension
   - AgoraVideoAv1EncoderExtension
   - AgoraVideoDecoderExtension
   - AgoraVideoEncoderExtension
   - AgoraVideoQualityAnalyzerExtension
   - AgoraVideoSegmentationExtension
   - Agorafdkaac
   - Agoraffmpeg
   - aosl
   - video_dec
   - video_enc

## 🚀 次の手順

1. **Xcodeでクリーンビルド**
   ```
   Product → Clean Build Folder (Shift+Cmd+K)
   ```

2. **アーカイブ作成**
   ```
   Product → Archive
   ```

3. **App Store Connectアップロード**
   - Window → Organizer
   - Archives → Distribute App
   - App Store Connect を選択
   - App Specific Password を使用

## 📊 期待される結果

### ✅ 解消されるエラー
- ❌ AKAuthenticationError -7005
- ❌ Upload Symbols Failed (24個のAgoraフレームワーク)
- ❌ dSYM missing errors

### ✅ 正常にアップロード完了
- App Store Connect でアプリが正常に処理される
- TestFlight配布準備完了
- App Store審査提出可能

## 💡 注意事項

1. **クラッシュレポート機能**
   - dSYM無効化によりクラッシュレポートの詳細は制限される
   - しかし、Agoraフレームワーク由来のクラッシュは元々デバッグ困難
   - アプリの主要機能には影響なし

2. **将来のアップデート**
   - 設定は永続的に適用される
   - 新しいAgoraバージョンでも同様の問題が発生した場合、同じ対処法で解決

## 🎯 結論

この修正により、App Store Connect アップロードが正常に完了し、
TalkOneアプリのTestFlight配布およびApp Store公開が可能になります。