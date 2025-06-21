import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/call_history_service.dart';
import '../services/agora_call_service.dart';
import 'evaluation_screen.dart';

// テーマ用データクラス
class AppThemePalette {
  final Color backgroundColor;
  final Color barColor;
  final Color callIconColor;

  const AppThemePalette({
    required this.backgroundColor,
    required this.barColor,
    required this.callIconColor,
  });
}

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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final UserProfileService _userProfileService = UserProfileService();
  final CallHistoryService _callHistoryService = CallHistoryService();
  final AgoraCallService _agoraService = AgoraCallService();
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  String _partnerNickname = 'Unknown';
  
  // Agora関連の状態
  bool _isConnected = false;
  bool _isMuted = false;
  bool _partnerJoined = false;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;
  
  // 音声レベルによるアイコンサイズ制御
  int _currentAudioVolume = 0;
  late AnimationController _volumeController;
  late Animation<double> _volumeAnimation;
  // テーマパレット定義
  final List<AppThemePalette> _appThemes = [
    // 1. デフォルト
    const AppThemePalette(
      backgroundColor: Color(0xFF5A64ED),
      barColor: Color(0xFF979CDE),
      callIconColor: Color(0xFF4CAF50),
    ),
    // 2. E6D283, EAC77A, F59A3E
    const AppThemePalette(
      backgroundColor: Color(0xFFE6D283),
      barColor: Color(0xFFEAC77A),
      callIconColor: Color(0xFFF59A3E),
    ),
    // 3. A482E5, D7B3E8, D487E6
    const AppThemePalette(
      backgroundColor: Color(0xFFA482E5),
      barColor: Color(0xFFD7B3E8),
      callIconColor: Color(0xFFD487E6),
    ),
    // 4. 83C8E6, B8D8E6, 618DAA
    const AppThemePalette(
      backgroundColor: Color(0xFF83C8E6),
      barColor: Color(0xFFB8D8E6),
      callIconColor: Color(0xFF618DAA),
    ),
    // 5. F0941F, EF6024, 548AB6
    const AppThemePalette(
      backgroundColor: Color(0xFFF0941F),
      barColor: Color(0xFFEF6024),
      callIconColor: Color(0xFF548AB6),
    ),
  ];
  int _selectedThemeIndex = 0;
  
  // タイマー関連
  int _remainingSeconds = 180; // 3分 = 180秒
  Timer? _timer;
  bool _callEnded = false;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now();
    _loadUserProfile();
    _initializeAnimations();
    _initializeVolumeAnimation();
    _initializeAgora();
    _startCallTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _volumeController.dispose();
    _agoraService.dispose();
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
  }
  
  void _initializeVolumeAnimation() {
    _volumeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _volumeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _volumeController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _loadUserProfile() async {
    // 相手のプロフィール情報を取得
    final partnerProfile = await _userProfileService.getUserProfileById(widget.partnerId);
    
    if (partnerProfile != null && mounted) {
      setState(() {
        // 相手の情報（アイコン、ニックネーム、テーマカラー）
        _selectedIconPath = partnerProfile.iconPath ?? 'aseets/icons/Woman 1.svg';
        _partnerNickname = partnerProfile.nickname ?? 'Unknown';
        _selectedThemeIndex = partnerProfile.themeIndex ?? 0;
      });
    }
  }

  Future<void> _initializeAgora() async {
    try {
      // Agoraサービスのコールバックを設定
      _agoraService.onUserJoined = (uid) {
        print('VoiceCall: 相手が参加しました - $uid');
        if (mounted) {
          setState(() {
            _partnerJoined = true;
          });
        }
      };

      _agoraService.onUserLeft = (uid) {
        print('VoiceCall: 相手が離脱しました - $uid');
        if (mounted) {
          setState(() {
            _partnerJoined = false;
          });
        }
      };

      _agoraService.onConnectionStateChanged = (state) {
        print('VoiceCall: 接続状態変更 - $state');
        if (mounted) {
          setState(() {
            _connectionState = state;
            _isConnected = state == AgoraConnectionState.connected;
          });
        }
      };
      
      // 音声レベル監視を設定
      _agoraService.onAudioVolumeIndication = (volume) {
        _updateAudioVolume(volume);
      };

      _agoraService.onError = (error) {
        print('VoiceCall: Agoraエラー - $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('通話エラー: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      // Agoraエンジンを初期化
      print('VoiceCall: Agora初期化開始...');
      
      // 複数回試行（iOS用）
      bool success = false;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (!success && retryCount < maxRetries && mounted) {
        if (retryCount > 0) {
          print('VoiceCall: 初期化リトライ ${retryCount}/${maxRetries}');
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }
        
        success = await _agoraService.initialize();
        
        if (!success) {
          retryCount++;
          if (retryCount < maxRetries) {
            print('VoiceCall: 初期化失敗、リトライします...');
          }
        }
      }
      
      if (success && mounted) {
        print('VoiceCall: Agora初期化成功、チャンネル参加中...');
        // チャンネルに参加
        final joinSuccess = await _agoraService.joinChannel(widget.channelName);
        
        if (joinSuccess) {
          print('VoiceCall: チャンネル参加成功 - ${widget.channelName}');
          _agoraService.recordCallStart();
        } else {
          print('VoiceCall: チャンネル参加失敗');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('通話に参加できませんでした。ネットワーク接続を確認してください。'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('VoiceCall: Agora初期化失敗（最大リトライ回数到達）');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('音声通話の初期化に失敗しました。マイクの権限を確認してください。'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('VoiceCall: Agora初期化エラー - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('通話エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCallTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _endCall();
      }
    });
  }

  Future<void> _toggleMute() async {
    try {
      await _agoraService.toggleMute();
      final newMuteState = await _agoraService.isMuted();
      if (mounted) {
        setState(() {
          _isMuted = newMuteState;
        });
      }
      print('VoiceCall: ミュート状態変更 - $_isMuted');
    } catch (e) {
      print('VoiceCall: ミュート切り替えエラー - $e');
    }
  }

  void _endCall() {
    if (_callEnded) return;
    _callEnded = true;
    
    _timer?.cancel();
    
    // Agoraから離脱
    _agoraService.leaveChannel();
    
    // 通話履歴を保存
    _saveCallHistory();
    
    // 直接評価画面に遷移
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => EvaluationScreen(
            callId: widget.callId,
            partnerId: widget.partnerId,
            isDummyMatch: false, // 通話のみバージョンではAI通話なし
            // isDummyMatch: widget.partnerId.startsWith('dummy_') || 
            //              widget.partnerId.startsWith('ai_practice_'),
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _saveCallHistory() async {
    if (_callStartTime == null) return;
    
    final callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
    // final isAiCall = widget.partnerId.startsWith('dummy_') || 
    //                  widget.partnerId.startsWith('ai_practice_');
    
    final history = CallHistory(
      callId: widget.callId,
      partnerId: widget.partnerId,
      partnerNickname: _partnerNickname,
      partnerIconPath: _selectedIconPath ?? 'aseets/icons/Woman 1.svg',
      callDateTime: _callStartTime!,
      callDuration: callDuration,
      isAiCall: false, // 通話のみバージョンではAI通話なし
    );
    
    await _callHistoryService.saveCallHistory(history);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color get _currentThemeColor => _appThemes[_selectedThemeIndex].backgroundColor;
  
  // 音声レベルを更新してアイコンサイズを変更
  void _updateAudioVolume(int volume) {
    if (!mounted) return;
    
    _currentAudioVolume = volume;
    
    // 音声レベル（0-255）を1.0-1.2のスケールに変換
    final normalizedVolume = (volume / 255.0).clamp(0.0, 1.0);
    final targetScale = 1.0 + (normalizedVolume * 0.2); // 最大1.2倍
    
    // アニメーションで滑らかにスケール変更
    _volumeController.animateTo(normalizedVolume);
    
    print('VoiceCall: 音声レベル $volume -> スケール ${targetScale.toStringAsFixed(2)}');
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _appThemes[_selectedThemeIndex];
    return Scaffold(
      backgroundColor: currentTheme.backgroundColor,
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
            // 接続状態表示
            _buildConnectionStatus(),
            
            // ユーザーアイコン
            Center(child: _buildUserIcon()),
            
            // 3分間タイマー
            Center(child: _buildTimer()),
            
            // 通話コントロール（ミュート・通話切り）
            Center(child: _buildCallControls()),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _volumeAnimation]),
      builder: (context, child) {
        // 基本のパルス + 音声レベルによる拡大
        final combinedScale = _pulseAnimation.value * _volumeAnimation.value;
        
        return Transform.scale(
          scale: combinedScale,
          child: Container(
            width: 234, // 180 * 1.3 = 234
            height: 234, // 180 * 1.3 = 234
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                // 音声レベルが高い時の追加エフェクト
                if (_currentAudioVolume > 30)
                  BoxShadow(
                    color: _appThemes[_selectedThemeIndex].backgroundColor.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
              ],
            ),
            child: ClipOval(
              child: SvgPicture.asset(
                _selectedIconPath!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
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
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: _appThemes[_selectedThemeIndex].backgroundColor,
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    String statusText;
    Color statusColor;
    
    switch (_connectionState) {
      case AgoraConnectionState.connecting:
        statusText = '接続中...';
        statusColor = Colors.orange;
        break;
      case AgoraConnectionState.connected:
        statusText = _partnerJoined ? '通話中' : '相手を待機中';
        statusColor = _partnerJoined ? Colors.green : Colors.blue;
        break;
      case AgoraConnectionState.failed:
        statusText = '接続エラー';
        statusColor = Colors.red;
        break;
      case AgoraConnectionState.disconnected:
      default:
        statusText = '未接続';
        statusColor = Colors.grey;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // ミュートボタン
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _isMuted ? Colors.red : Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: _toggleMute,
              child: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: _isMuted ? Colors.white : _appThemes[_selectedThemeIndex].backgroundColor,
                size: 28,
              ),
            ),
          ),
        ),
        
        // 通話終了ボタン
        Container(
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
              onTap: _endCall,
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ],
    );
  }
}