import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/call_history_service.dart';
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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final UserProfileService _userProfileService = UserProfileService();
  final CallHistoryService _callHistoryService = CallHistoryService();
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  String _partnerNickname = 'Unknown';
  final List<Color> _themeColors = [
    const Color(0xFF5A64ED), // Default Blue
    const Color(0xFFE6D283), // Golden
    const Color(0xFFA482E5), // Purple
    const Color(0xFF83C8E6), // Blue
    const Color(0xFFF0941F), // Orange
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
    _startCallTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
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

  void _endCall() {
    if (_callEnded) return;
    _callEnded = true;
    
    _timer?.cancel();
    
    // 通話履歴を保存
    _saveCallHistory();
    
    // 直接評価画面に遷移
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => EvaluationScreen(
            callId: widget.callId,
            partnerId: widget.partnerId,
            isDummyMatch: widget.partnerId.startsWith('dummy_') || 
                         widget.partnerId.startsWith('ai_practice_'),
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _saveCallHistory() async {
    if (_callStartTime == null) return;
    
    final callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
    final isAiCall = widget.partnerId.startsWith('dummy_') || 
                     widget.partnerId.startsWith('ai_practice_');
    
    final history = CallHistory(
      callId: widget.callId,
      partnerId: widget.partnerId,
      partnerNickname: _partnerNickname,
      partnerIconPath: _selectedIconPath ?? 'aseets/icons/Woman 1.svg',
      callDateTime: _callStartTime!,
      callDuration: callDuration,
      isAiCall: isAiCall,
    );
    
    await _callHistoryService.saveCallHistory(history);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color get _currentThemeColor => _themeColors[_selectedThemeIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
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
            // ユーザーアイコン
            Center(child: _buildUserIcon()),
            
            // 3分間タイマー
            Center(child: _buildTimer()),
            
            // 通話切りボタン
            Center(child: _buildEndCallButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
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
          color: _currentThemeColor,
        ),
      ),
    );
  }

  Widget _buildEndCallButton() {
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
          onTap: _endCall,
          child: const Icon(
            Icons.call_end,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}