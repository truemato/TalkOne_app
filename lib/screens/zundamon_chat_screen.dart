import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/user_profile_service.dart';
import '../services/voicevox_service.dart';
import '../services/conversation_data_service.dart';
import 'home_screen.dart';

class ZundamonChatScreen extends StatefulWidget {
  const ZundamonChatScreen({super.key});

  @override
  State<ZundamonChatScreen> createState() => _ZundamonChatScreenState();
}

class _ZundamonChatScreenState extends State<ZundamonChatScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _listeningController;
  late Animation<double> _listeningAnimation;
  
  // Gemini AI関連
  late GenerativeModel _aiModel;  // 2.5 Flash (テキスト生成)
  late GenerativeModel _liveModel; // 2.0 Flash Live (音声合成)
  late ChatSession _chatSession;
  bool _isInitialized = false;
  bool _isProcessing = false;
  
  // 音声認識関連
  final SpeechToText _speech = SpeechToText();
  static const MethodChannel _androidSpeechChannel = MethodChannel('android_speech_recognizer');
  bool _isListening = false;
  int _androidRetryCount = 0;
  
  // 音声合成関連（Gemini 2.0 Flash Live使用）
  final VoiceVoxService _voiceVoxService = VoiceVoxService(); // fallback用
  final FlutterTts _flutterTts = FlutterTts(); // システムデフォルト音声
  
  // サービス
  final UserProfileService _userProfileService = UserProfileService();
  final ConversationDataService _conversationService = ConversationDataService();
  
  // UI状態
  String _userSpeechText = '';
  String _aiResponseText = 'こんにちは！Gemini 2.0 Flash です。何かお話ししましょう！';
  String _errorMessage = '';
  
  // 3分タイマー
  int _remainingSeconds = 180; // 3分 = 180秒
  Timer? _timer;
  bool _chatEnded = false;
  DateTime? _chatStartTime;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _chatStartTime = DateTime.now();
    _initializeAnimations();
    _initializeGeminiChat();
    _startChatTimer();
  }

  @override
  void dispose() {
    // フラグをセットして非同期処理を停止
    _chatEnded = true;
    
    // タイマー停止
    _timer?.cancel();
    
    // アニメーション停止・破棄
    _pulseController.stop();
    _pulseController.dispose();
    _listeningController.stop();
    _listeningController.dispose();
    
    // 音声認識停止
    try {
      _speech.cancel();
      _speech.stop();
    } catch (e) {
      print('Speech disposal error: $e');
    }
    
    // Android音声認識チャンネル解除
    try {
      if (Platform.isAndroid) {
        _androidSpeechChannel.setMethodCallHandler(null);
      }
    } catch (e) {
      print('Android speech channel disposal error: $e');
    }
    
    // VoiceVox停止
    try {
      _voiceVoxService.dispose();
    } catch (e) {
      print('VoiceVox disposal error: $e');
    }
    
    // FlutterTTS停止
    try {
      _flutterTts.stop();
    } catch (e) {
      print('FlutterTTS disposal error: $e');
    }
    
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _listeningController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _listeningAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _listeningController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeGeminiChat() async {
    try {
      print('Gemini 2.0 Flash 初期化開始');
      
      // 音声認識初期化
      if (Platform.isIOS) {
        final speechAvailable = await _speech.initialize(
          onError: (error) {
            print('Speech initialization error: ${error.errorMsg}');
            setState(() {
              _errorMessage = error.errorMsg;
            });
          },
          onStatus: (status) => print('Speech status: $status'),
          debugLogging: true,
          finalTimeout: const Duration(seconds: 5),
        );
        
        if (!speechAvailable) {
          setState(() {
            _errorMessage = '音声認識が利用できません';
          });
          return;
        }
      } else {
        // Android用音声認識初期化
        try {
          final result = await _androidSpeechChannel.invokeMethod('initialize');
          if (result != true) {
            setState(() {
              _errorMessage = 'Android音声認識の初期化に失敗しました';
            });
            return;
          }
          _androidSpeechChannel.setMethodCallHandler(_handleAndroidSpeechResult);
        } catch (e) {
          print('Android SpeechRecognizer 初期化エラー: $e');
          setState(() {
            _errorMessage = 'Android音声認識が利用できません';
          });
          return;
        }
      }
      
      // ユーザーのAIメモリを取得
      String userMemory = '';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _userProfileService.getUserProfile();
        userMemory = profile?.aiMemory ?? '';
        print('ユーザーAIメモリ取得: "$userMemory"');
      }
      
      // Gemini 2.0 Flash システムプロンプト
      final systemPrompt = '''
あなたは親しみやすいAIアシスタントです。自然で楽しい会話を心がけてください。

【会話ルール】
1. 必ず80文字以内で返答すること（重要！）
2. 相手を元気づけて励ます
3. 自然で親しみやすい口調
4. 難しい専門用語は避ける
5. わからないことは素直に「わかりません」と言う

${userMemory.isNotEmpty ? '''
【この人について覚えておくこと】
$userMemory

この情報を参考にして、より個人的で親しみやすい会話をしてください。
''' : ''}

例:
相手「疲れたな...」
AI「お疲れ様です！少し休憩して、好きなことでもして気分転換してみてはいかがですか？」
''';

      // Gemini 2.5 Flash モデル初期化（テキスト生成用）
      _aiModel = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.5-flash-002',
        systemInstruction: Content.text(systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.8,
          maxOutputTokens: 50, // 80文字制限のため
          topP: 0.9,
          topK: 40,
        ),
      );
      
      // Gemini 2.0 Flash Live モデル初期化（音声合成用）
      _liveModel = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.0-flash-live-001',
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 100,
        ),
      );
      
      _chatSession = _aiModel.startChat();
      
      // VoiceVoxServiceでずんだもんを設定（fallback用）
      _voiceVoxService.setSpeaker(3); // ずんだもん
      
      // 会話セッション開始
      if (user != null) {
        _sessionId = await _conversationService.startConversationSession(
          partnerId: 'gemini_2_0_flash',
          type: ConversationType.voice,
          isAIPartner: true,
        );
      }
      
      setState(() {
        _isInitialized = true;
      });
      
      print('Gemini 2.0 Flash 初期化完了');
      
      // 自動で音声認識開始
      await _startListening();
      
    } catch (e) {
      print('Gemini 2.0 Flash 初期化エラー: $e');
      setState(() {
        _errorMessage = '初期化エラー: $e';
      });
    }
  }

  Future<void> _handleAndroidSpeechResult(MethodCall call) async {
    // チャット終了済みの場合は処理しない
    if (_chatEnded || !mounted) return;
    
    switch (call.method) {
      case 'onResults':
        final results = List<String>.from(call.arguments['results']);
        if (results.isNotEmpty && !_chatEnded) {
          final recognizedText = results.first;
          print('Android SpeechRecognizer結果: "$recognizedText"');
          
          if (mounted) {
            setState(() {
              _userSpeechText = recognizedText;
            });
          }
          
          if (recognizedText.trim().isNotEmpty && _isListening && !_chatEnded) {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
            _listeningController.stop();
            _listeningController.reset();
            _processUserInput(recognizedText.trim());
          }
        }
        break;
        
      case 'onError':
        final errorCode = call.arguments['errorCode'] as int;
        final errorMessage = call.arguments['errorMessage'] as String;
        print('Android SpeechRecognizer エラー: $errorCode - $errorMessage');
        
        if (mounted && !_chatEnded) {
          setState(() {
            _isListening = false;
          });
        }
        _listeningController.stop();
        _listeningController.reset();
        
        // チャット終了していない場合のみリトライ
        if (!_chatEnded && errorCode == 7 && _androidRetryCount < 3) { // ERROR_NO_MATCH
          _androidRetryCount++;
          Future.delayed(const Duration(seconds: 2), () {
            if (!_chatEnded && _isInitialized && !_isProcessing && mounted) {
              _startListening();
            }
          });
        }
        break;
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized || _isListening || _chatEnded || !mounted) return;
    
    try {
      if (mounted) {
        setState(() {
          _isListening = true;
          _userSpeechText = '';
        });
      }
      _listeningController.repeat(reverse: true);
      
      if (Platform.isAndroid) {
        await _androidSpeechChannel.invokeMethod('startListening', {
          'locale': 'ja-JP',
          'maxResults': 1,
          'partialResults': true,
        });
      } else {
        await _speech.listen(
          onResult: (result) {
            if (!_chatEnded && mounted) {
              setState(() {
                _userSpeechText = result.recognizedWords;
              });
              
              if (result.finalResult && result.recognizedWords.trim().isNotEmpty && !_chatEnded) {
                print('iOS AIに送信: ${result.recognizedWords}');
                _processUserInput(result.recognizedWords.trim());
              }
            }
          },
          localeId: 'ja-JP',
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 60),
        );
      }
    } catch (e) {
      print('音声認識開始エラー: $e');
      if (mounted && !_chatEnded) {
        setState(() {
          _isListening = false;
          _errorMessage = '音声認識エラー: $e';
        });
      }
    }
  }

  Future<void> _processUserInput(String userText) async {
    if (userText.isEmpty || _isProcessing || _chatEnded || !mounted) return;
    
    if (mounted) {
      setState(() {
        _isProcessing = true;
        _isListening = false;
      });
    }
    
    try {
      print('Gemini 2.0 Flash AIに送信: $userText');
      
      // 会話ログ保存
      if (_sessionId != null) {
        await _conversationService.saveVoiceMessage(
          sessionId: _sessionId!,
          speakerId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
          transcribedText: userText,
          confidence: 1.0,
          timestamp: DateTime.now(),
        );
      }
      
      // AI応答生成
      final response = await _chatSession.sendMessage(Content.text(userText));
      var aiText = response.text ?? '';
      
      // 80文字制限の適用
      if (aiText.length > 80) {
        aiText = aiText.substring(0, 80);
        final lastSentence = aiText.lastIndexOf('。');
        if (lastSentence > 30) {
          aiText = aiText.substring(0, lastSentence + 1);
        }
      }
      
      if (aiText.isNotEmpty && !_chatEnded) {
        if (mounted) {
          setState(() {
            _aiResponseText = aiText;
          });
        }
        
        // AI応答もログ保存
        if (_sessionId != null && !_chatEnded) {
          await _conversationService.saveVoiceMessage(
            sessionId: _sessionId!,
            speakerId: 'gemini_2_0_flash',
            transcribedText: aiText,
            confidence: 1.0,
            timestamp: DateTime.now(),
            metadata: {'isAI': true},
          );
        }
        
        // Gemini 2.0 Flash Live音声合成
        if (!_chatEnded) {
          await _speakWithGeminiLive(aiText);
        }
      }
    } catch (e) {
      print('AI応答エラー: $e');
      if (mounted && !_chatEnded) {
        setState(() {
          _errorMessage = 'AI応答エラー: $e';
        });
      }
    } finally {
      if (mounted && !_chatEnded) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _speakWithGeminiLive(String text) async {
    try {
      print('Gemini 2.0 Flash Live音声合成開始: $text');
      
      // Gemini 2.0 Flash Liveに音声合成を指示
      final audioPrompt = 'Generate natural Japanese speech with friendly, energetic tone: $text';
      
      final response = await _liveModel.generateContent([
        Content.text(audioPrompt)
      ]);
      
      // 現在のSDKでは音声データの直接取得が制限されているため
      // デフォルトのflutter_ttsを使用してテキストを音声に変換
      if (response.text != null && response.text!.isNotEmpty) {
        await _playTextWithTTS(text);
      } else {
        // fallbackとしてVoiceVoxを使用
        await _speakWithVoicevoxFallback(text);
      }
      
      // 音声認識再開
      if (_isInitialized && !_isListening && !_chatEnded) {
        await Future.delayed(const Duration(milliseconds: 500));
        _androidRetryCount = 0;
        await _startListening();
      }
    } catch (e) {
      print('Gemini Live音声合成エラー: $e');
      // エラー時はVoiceVoxにフォールバック
      await _speakWithVoicevoxFallback(text);
    }
  }
  
  Future<void> _playTextWithTTS(String text) async {
    try {
      // システムデフォルト音声で高速・自然な音声合成
      await _flutterTts.setLanguage('ja-JP');
      await _flutterTts.setSpeechRate(0.6); // 少し速めに設定
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      print('システムTTS音声合成開始: $text');
      await _flutterTts.speak(text);
      
      // 音声再生完了を待つ（より正確な計算）
      final waitTime = (text.length * 100).clamp(1500, 6000);
      await Future.delayed(Duration(milliseconds: waitTime));
      
    } catch (e) {
      print('TTS音声再生エラー: $e');
    }
  }
  
  Future<void> _speakWithVoicevoxFallback(String text) async {
    try {
      print('VoiceVox fallback音声合成: $text');
      
      final success = await _voiceVoxService.speak(text);
      
      if (success) {
        // 音声再生完了を待つ
        final waitTime = (text.length * 80).clamp(2000, 8000);
        await Future.delayed(Duration(milliseconds: waitTime));
      }
    } catch (e) {
      print('VoiceVox fallback音声合成エラー: $e');
    }
  }

  void _startChatTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _endChat();
      }
    });
  }

  void _endChat() {
    if (_chatEnded) return;
    
    _chatEnded = true;
    _timer?.cancel();
    
    // 音声認識停止
    setState(() {
      _isListening = false;
      _isProcessing = false;
    });
    
    // 会話セッション終了（非同期だがawaitしない）
    if (_sessionId != null) {
      _conversationService.endConversationSession(
        sessionId: _sessionId!,
        actualDurationSeconds: 180,
        endReason: ConversationEndReason.timeLimit,
      ).catchError((error) {
        print('セッション終了エラー: $error');
      });
    }
    
    // 遅延してナビゲーション実行（リソース解放を待つ）
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A64ED), // Gemini Blue
      body: Platform.isAndroid 
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // エラーメッセージ表示
            if (_errorMessage.isNotEmpty) _buildErrorMessage(),
            
            // Geminiアイコン
            Center(child: _buildGeminiIcon()),
            
            // 会話内容表示
            Center(child: _buildConversationDisplay()),
            
            // 3分間タイマー
            Center(child: _buildTimer()),
            
            // 終了ボタン
            Center(child: _buildEndButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _listeningAnimation]),
      builder: (context, child) {
        final scale = _isListening 
            ? _pulseAnimation.value * _listeningAnimation.value
            : _pulseAnimation.value;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                // 音声認識中の青色エフェクト
                if (_isListening)
                  BoxShadow(
                    color: const Color(0xFF4285F4).withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
              ],
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF5A64ED),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationDisplay() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 150),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // AI応答
          if (_aiResponseText.isNotEmpty)
            Text(
              'Gemini: $_aiResponseText',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A73E8),
              ),
              textAlign: TextAlign.center,
            ),
          
          const SizedBox(height: 8),
          
          // ユーザー発言
          if (_userSpeechText.isNotEmpty)
            Text(
              'あなた: $_userSpeechText',
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          
          // 音声認識状態
          if (_isListening && _userSpeechText.isEmpty)
            Text(
              '聞いています...',
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _formatTime(_remainingSeconds),
        style: GoogleFonts.notoSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A73E8),
        ),
      ),
    );
  }

  Widget _buildEndButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: _endChat,
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        _errorMessage,
        style: GoogleFonts.notoSans(
          fontSize: 12,
          color: Colors.red[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}