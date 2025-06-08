// lib/screens/voice_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/agora_call_service.dart';
import '../services/call_matching_service.dart';
import '../config/agora_config.dart';
import 'evaluation_screen.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String callId;
  final String partnerId;

  const VoiceCallScreen({
    super.key,
    required this.channelName,
    required this.callId,
    required this.partnerId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  final AgoraCallService _agoraService = AgoraCallService();
  final CallMatchingService _matchingService = CallMatchingService();
  
  bool _isConnected = false;
  bool _isMuted = false;
  bool _partnerJoined = false;
  int _remainingSeconds = AgoraConfig.callDurationSeconds;
  String _connectionStatus = '接続中...';
  int _myVolume = 0;
  int _partnerVolume = 0;
  
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _callEnded = false; // 通話終了済みフラグ
  
  @override
  void initState() {
    super.initState();
    
    // パルスアニメーション設定
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _initializeCall();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _agoraService.dispose();
    super.dispose();
  }
  
  Future<void> _initializeCall() async {
    // Agoraコールバック設定
    _agoraService.onUserJoined = (uid) {
      if (!mounted) return;
      setState(() {
        _partnerJoined = true;
        _connectionStatus = '通話中';
      });
      _startCallTimer();
      print('相手が参加しました: $uid');
    };
    
    _agoraService.onUserLeft = (uid) {
      if (!mounted) return;
      print('相手が退出しました: $uid');
      setState(() {
        _partnerJoined = false;
        _connectionStatus = '相手が退出しました';
      });
      // 少し遅延させてから通話終了処理を実行
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _endCall(reason: '相手が通話を終了しました');
        }
      });
    };
    
    _agoraService.onConnectionStateChanged = (state) {
      if (!mounted) return;
      setState(() {
        _isConnected = state == AgoraConnectionState.connected;
        switch (state) {
          case AgoraConnectionState.connecting:
            _connectionStatus = '接続中...';
            break;
          case AgoraConnectionState.connected:
            _connectionStatus = '接続完了';
            break;
          case AgoraConnectionState.disconnected:
            _connectionStatus = '接続切断';
            // 通話中に接続が切断された場合、通話終了処理を実行
            if (_partnerJoined) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) {
                  _endCall(reason: '接続が切断されました');
                }
              });
            }
            break;
          case AgoraConnectionState.failed:
            _connectionStatus = '接続失敗';
            break;
          case AgoraConnectionState.reconnecting:
            _connectionStatus = '再接続中...';
            break;
        }
      });
    };
    
    _agoraService.onError = (error) {
      _showErrorDialog(error);
    };
    
    _agoraService.onAudioVolumeIndication = (volume) {
      if (!mounted) return;
      setState(() {
        _myVolume = volume;
      });
      
      // ボリュームに応じてパルスアニメーション
      if (volume > 10) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    };
    
    // Agora初期化
    final initialized = await _agoraService.initialize();
    if (!initialized) {
      _showErrorDialog('音声通話の初期化に失敗しました');
      return;
    }
    
    // チャンネル参加
    final joined = await _agoraService.joinChannel(widget.channelName);
    if (!joined) {
      _showErrorDialog('通話チャンネルへの参加に失敗しました');
      return;
    }
    
    if (mounted) {
      setState(() {
        _connectionStatus = '相手の参加を待っています...';
      });
    }
    
    // AI通話の場合は即座にタイマー開始
    if (widget.partnerId.startsWith('ai_practice_') || widget.partnerId.startsWith('dummy_')) {
      setState(() {
        _partnerJoined = true;
        _connectionStatus = 'AI通話中';
      });
      _startCallTimer();
      print('AI通話を開始しました');
    }
  }
  
  void _startCallTimer() {
    if (_timer != null) return; // 既にタイマーが動いている場合は何もしない
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _endCall(reason: '通話時間が終了しました');
      }
    });
  }
  
  Future<void> _toggleMute() async {
    await _agoraService.toggleMute();
    final muted = await _agoraService.isMuted();
    if (mounted) {
      setState(() {
        _isMuted = muted;
      });
    }
  }
  
  void _endCall({String reason = '通話を終了しました'}) {
    if (_callEnded) return; // 既に終了処理中の場合は何もしない
    _callEnded = true;
    
    print('通話終了処理開始: $reason');
    _timer?.cancel();
    
    // 通話終了を記録
    _matchingService.finishCall(widget.callId);
    
    // Agoraから離脱
    _agoraService.leaveChannel();
    
    // 評価画面に直接遷移
    _navigateToEvaluation();
  }
  
  void _cancelCall() {
    if (_callEnded) return;
    _callEnded = true;
    
    print('通話キャンセル処理開始');
    _timer?.cancel();
    
    // 通話キャンセルを記録
    _matchingService.cancelCallRequest(widget.callId);
    
    // Agoraから離脱
    _agoraService.leaveChannel();
    
    // ホーム画面に戻る
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToEvaluation() {
    // 全ての既存画面をクリアして評価画面に遷移
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => EvaluationScreen(
          callId: widget.callId,
          partnerId: widget.partnerId,
          isDummyMatch: widget.partnerId.startsWith('dummy_') || 
                       widget.partnerId.startsWith('ai_practice_'),
        ),
      ),
      (route) => false, // 全ての前の画面を削除
    );
  }
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('エラー'),
          content: Text(error),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('戻る'),
            ),
          ],
        );
      },
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_connectionStatus),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _cancelCall(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // タイマー表示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // 相手の状態表示
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _partnerJoined && _partnerVolume > 10 
                            ? _pulseAnimation.value 
                            : 1.0,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _partnerJoined 
                                ? Colors.green.withOpacity(0.7)
                                : Colors.grey.withOpacity(0.7),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _partnerJoined ? Icons.person : Icons.person_outline,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _partnerJoined ? '相手' : '相手を待っています...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              
              // 自分の状態表示
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _myVolume > 10 ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMuted 
                                ? Colors.red.withOpacity(0.7)
                                : Colors.blue.withOpacity(0.7),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _isMuted ? Icons.mic_off : Icons.mic,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isMuted ? 'ミュート中' : 'あなた',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              
              // 通話コントロール
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ミュートボタン
                  FloatingActionButton(
                    heroTag: "mute",
                    backgroundColor: _isMuted ? Colors.red : Colors.grey[700],
                    foregroundColor: Colors.white,
                    onPressed: _toggleMute,
                    child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  ),
                  
                  // 通話終了ボタン
                  FloatingActionButton(
                    heroTag: "end_call",
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    onPressed: () => _endCall(),
                    child: const Icon(Icons.call_end, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}