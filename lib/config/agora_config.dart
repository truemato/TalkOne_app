// lib/config/agora_config.dart
class AgoraConfig {
  // Agora App ID (開発用の一時的なもの、本番では環境変数から取得)
  static const String appId = "4067eac9200f4aebb0fcf1b190eabd7d";
  
  // テスト用のチャンネル設定
  static const String channelPrefix = "talkone_";
  
  // 音声品質設定
  static const int sampleRate = 16000;
  static const int bitrate = 32000;
  
  // 通話時間制限（秒）
  static const int callDurationSeconds = 180; // 3分
  
  // 一時的なトークン（本番では動的生成が必要）
  static const String tempToken = "";
  
  // Agoraプロジェクト設定
  static Map<String, dynamic> get rtcEngineConfig => {
    'appId': appId,
    'channelProfile': 1, // Communication
    'audioProfile': 2,   // Music standard
    'audioScenario': 3,  // ChatRoom
  };
}