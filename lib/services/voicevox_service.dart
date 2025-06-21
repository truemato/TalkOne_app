// AI機能無効化のためVOICEVOXサービス全体をコメントアウト
/*
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

/// VOICEVOX音声合成サービス
/// 
/// VOICEVOX Engineを使用して高品質な音声合成を提供します。
/// 様々な話者（キャラクター）と音声パラメータの調整が可能です。
class VoiceVoxService {
  static const String _defaultHost = "https://voicevox-engine-198779252752.asia-northeast1.run.app"; // GCP Cloud Run URL
  static const String _localHost = "http://127.0.0.1:50021"; // ローカル開発用
  static const String _fallbackHost = "https://api.su-shiki.com/v2/voicevox"; // 代替API（将来の実装用）
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _host;
  bool _useLocalEngine;
  
  // 音声パラメータ
  int _speakerId = 1;
  double _speed = 1.0;
  double _pitch = 0.0;
  double _intonation = 1.0;
  double _volume = 1.0;
  
  VoiceVoxService({
    String? host,
    bool useLocalEngine = false,
  }) : _host = host ?? (useLocalEngine ? _localHost : _defaultHost),
       _useLocalEngine = useLocalEngine;
  
  /// 話者IDを設定
  void setSpeaker(int speakerId) {
    _speakerId = speakerId;
  }
  
  /// 音声パラメータを設定
  void setVoiceParameters({
    double? speed,
    double? pitch,
    double? intonation,
    double? volume,
  }) {
    if (speed != null) _speed = speed;
    if (pitch != null) _pitch = pitch;
    if (intonation != null) _intonation = intonation;
    if (volume != null) _volume = volume;
  }
  
  /// ホストURLを変更（ローカル/クラウドの切り替え）
  void switchToLocalEngine() {
    _host = _localHost;
    _useLocalEngine = true;
  }
  
  void switchToCloudEngine() {
    _host = _defaultHost;
    _useLocalEngine = false;
  }
  
  /// VOICEVOX Engineが利用可能かチェック（フォールバック機能付き）
  Future<bool> isEngineAvailable() async {
    // 現在のホストをテスト
    if (await _testConnection(_host)) {
      return true;
    }
    
    // ローカルエンジンでない場合、ローカルにフォールバック
    if (!_useLocalEngine && await _testConnection(_localHost)) {
      print('Cloud Run接続失敗、ローカルエンジンに切り替え');
      _host = _localHost;
      _useLocalEngine = true;
      return true;
    }
    
    // クラウドエンジンでない場合、クラウドにフォールバック
    if (_useLocalEngine && await _testConnection(_defaultHost)) {
      print('ローカル接続失敗、クラウドエンジンに切り替え');
      _host = _defaultHost;
      _useLocalEngine = false;
      return true;
    }
    
    return false;
  }
  
  /// 指定したホストへの接続テスト
  Future<bool> _testConnection(String host) async {
    try {
      final response = await http.get(
        Uri.parse('$host/version'),
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('VOICEVOX Engine接続成功: $host');
        return true;
      }
    } catch (e) {
      print('VOICEVOX Engine接続失敗 ($host): $e');
    }
    return false;
  }
  
  /// 利用可能な話者リストを取得
  Future<List<VoiceVoxSpeaker>> getSpeakers() async {
    try {
      final response = await http.get(
        Uri.parse('$_host/speakers'),
        headers: {'accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((speaker) => VoiceVoxSpeaker.fromJson(speaker)).toList();
      }
      
      throw Exception('話者リスト取得失敗: ${response.statusCode}');
    } catch (e) {
      print('話者リスト取得エラー: $e');
      return [];
    }
  }
  
  /// テキストを音声合成して再生
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    
    try {
      // 1. audio_queryでパラメータ取得
      final queryUri = Uri.parse(
        '$_host/audio_query?'
        'text=${Uri.encodeComponent(text)}&'
        'speaker=$_speakerId',
      );
      
      final queryResponse = await http.post(
        queryUri,
        headers: {'accept': 'application/json'},
      );
      
      if (queryResponse.statusCode != 200) {
        throw Exception('audio_query失敗: ${queryResponse.statusCode}');
      }
      
      // 2. パラメータを調整
      final Map<String, dynamic> queryJson = jsonDecode(queryResponse.body);
      queryJson['speedScale'] = _speed;
      queryJson['pitchScale'] = _pitch;
      queryJson['intonationScale'] = _intonation;
      queryJson['volumeScale'] = _volume;
      
      // 3. synthesisで音声生成
      final synthUri = Uri.parse('$_host/synthesis?speaker=$_speakerId');
      final synthResponse = await http.post(
        synthUri,
        headers: {
          'accept': 'audio/wav',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(queryJson),
      );
      
      if (synthResponse.statusCode != 200) {
        throw Exception('synthesis失敗: ${synthResponse.statusCode}');
      }
      
      // 4. 音声再生
      await _audioPlayer.play(BytesSource(synthResponse.bodyBytes));
      return true;
      
    } catch (e) {
      print('音声合成エラー: $e');
      return false;
    }
  }
  
  /// 音声再生を停止
  Future<void> stop() async {
    await _audioPlayer.stop();
  }
  
  /// 再生中かチェック
  bool get isPlaying => _audioPlayer.state == PlayerState.playing;
  
  /// リソースの解放
  void dispose() {
    _audioPlayer.dispose();
  }
  
  /// 現在の設定を取得
  Map<String, dynamic> getCurrentSettings() {
    return {
      'host': _host,
      'useLocalEngine': _useLocalEngine,
      'speakerId': _speakerId,
      'speed': _speed,
      'pitch': _pitch,
      'intonation': _intonation,
      'volume': _volume,
    };
  }
}

/// VOICEVOX話者情報
class VoiceVoxSpeaker {
  final String name;
  final String speakerUuid;
  final List<VoiceVoxStyle> styles;
  final String version;
  
  VoiceVoxSpeaker({
    required this.name,
    required this.speakerUuid,
    required this.styles,
    required this.version,
  });
  
  factory VoiceVoxSpeaker.fromJson(Map<String, dynamic> json) {
    return VoiceVoxSpeaker(
      name: json['name'] ?? '',
      speakerUuid: json['speaker_uuid'] ?? '',
      styles: (json['styles'] as List? ?? [])
          .map((style) => VoiceVoxStyle.fromJson(style))
          .toList(),
      version: json['version'] ?? '',
    );
  }
}

/// VOICEVOX音声スタイル
class VoiceVoxStyle {
  final String name;
  final int id;
  final String type;
  
  VoiceVoxStyle({
    required this.name,
    required this.id,
    required this.type,
  });
  
  factory VoiceVoxStyle.fromJson(Map<String, dynamic> json) {
    return VoiceVoxStyle(
      name: json['name'] ?? '',
      id: json['id'] ?? 0,
      type: json['type'] ?? 'talk',
    );
  }
}

/// 人格に応じた話者設定
class PersonalityVoiceMapping {
  static const Map<int, VoiceConfig> _personalityVoiceMap = {
    1: VoiceConfig(speakerId: 1, speed: 1.0, pitch: 0.0, intonation: 1.0), // 親切
    2: VoiceConfig(speakerId: 3, speed: 1.2, pitch: 0.1, intonation: 1.2), // 活発
    3: VoiceConfig(speakerId: 0, speed: 0.9, pitch: -0.1, intonation: 0.9), // 穏やか
    4: VoiceConfig(speakerId: 2, speed: 1.1, pitch: 0.05, intonation: 1.1), // 知的
    5: VoiceConfig(speakerId: 4, speed: 0.95, pitch: 0.0, intonation: 1.0), // 優しい
  };
  
  static VoiceConfig? getVoiceConfig(int personalityId) {
    return _personalityVoiceMap[personalityId];
  }
}

/// 音声設定
class VoiceConfig {
  final int speakerId;
  final double speed;
  final double pitch;
  final double intonation;
  final double volume;
  
  const VoiceConfig({
    required this.speakerId,
    required this.speed,
    required this.pitch,
    required this.intonation,
    this.volume = 1.0,
  });
}
*/