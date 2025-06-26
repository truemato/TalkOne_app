import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/call_matching_service.dart';
import '../services/evaluation_service.dart';
import 'voice_call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreCallProfileScreen extends StatefulWidget {
  final CallMatch match;
  
  const PreCallProfileScreen({
    super.key,
    required this.match,
  });

  @override
  State<PreCallProfileScreen> createState() => _PreCallProfileScreenState();
}

class _PreCallProfileScreenState extends State<PreCallProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _bubbleController;
  late Animation<Offset> _bubbleAnimation;
  late AnimationController _rateController;
  late Animation<int> _rateAnimation;
  
  final UserProfileService _profileService = UserProfileService();
  UserProfile? _partnerProfile;
  UserProfile? _myProfile;
  bool _isLoading = true;
  int _partnerRating = 1000; // デフォルトレーティング
  String? _myIconPath = 'aseets/icons/Woman 1.svg'; // デフォルトアイコン

  // 背景アニメーションの状態管理
  int _currentBackgroundIndex = 0;
  final List<String> _backgroundAnimations = [
    'aseets/animations/background_animation(river).json',
  ];
  final List<String> _backgroundNames = [
    '川',
  ];

  // 背景アニメーションの表示設定
  final List<BoxFit> _backgroundFits = [
    BoxFit.cover,
  ];

  final List<Alignment> _backgroundAlignments = [
    Alignment.center,
  ];

  // HomeScreen2のStateにテーマインデックスを追加
  int _selectedThemeIndex = 0;

  // ユーザーの一言コメント用
  String _userComment = 'よろしくお願いします！';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadPartnerProfile();
    _loadMyProfile();
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    _bubbleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bubbleAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: const Offset(0, -0.02),
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeInOut,
    ));

    _rateController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rateAnimation = IntTween(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
    );
  }

  Future<void> _loadPartnerProfile() async {
    try {
      // 相手のプロフィールを取得
      final profile = await _getPartnerProfile(widget.match.partnerId);
      
      if (profile == null) {
        // プロフィールが存在しない場合、評価システムからレーティングを取得
        int actualRating = 1000;
        try {
          final evaluationService = EvaluationService();
          final ratingFromEvaluation = await evaluationService.getUserRating(widget.match.partnerId);
          actualRating = ratingFromEvaluation.toInt();
        } catch (e) {
          print('評価システムからのレーティング取得エラー: $e');
        }
        
        final defaultProfile = UserProfile(
          nickname: 'ずんだもん',
          gender: '回答しない',
          themeIndex: 0,
          rating: actualRating,
        );
        
        await _saveDefaultProfileForUser(widget.match.partnerId, defaultProfile);
        
        setState(() {
          _partnerProfile = defaultProfile;
          _isLoading = false;
          _partnerRating = actualRating;
        });
        
        // レートアニメーションを更新
        _rateController.reset();
        _rateAnimation = IntTween(begin: 0, end: _partnerRating).animate(
          CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
        );
        _rateController.forward();
      } else {
        // プロフィールが存在する場合、不足している値にデフォルト値を設定
        final updatedProfile = UserProfile(
          nickname: profile.nickname ?? 'ずんだもん',
          gender: profile.gender ?? '回答しない',
          birthday: profile.birthday,
          aiMemory: profile.aiMemory,
          iconPath: profile.iconPath,
          themeIndex: profile.themeIndex,
          rating: profile.rating,
        );
        
        setState(() {
          _partnerProfile = updatedProfile;
          _isLoading = false;
          _partnerRating = profile.rating;
        });
      }
      
      // レートアニメーションを更新
      _rateController.reset();
      _rateAnimation = IntTween(begin: 0, end: _partnerRating).animate(
        CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
      );
      _rateController.forward();
      
      // 3秒後に通話画面に遷移
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VoiceCallScreen(
                channelName: widget.match.channelName,
                callId: widget.match.callId,
                partnerId: widget.match.partnerId,
                conversationTheme: widget.match.conversationTheme,
              ),
            ),
          );
        }
      });
    } catch (e) {
      print('パートナープロフィール読み込みエラー: $e');
      // エラーの場合も評価システムからレーティングを取得
      int actualRating = 1000;
      try {
        final evaluationService = EvaluationService();
        final ratingFromEvaluation = await evaluationService.getUserRating(widget.match.partnerId);
        actualRating = ratingFromEvaluation.toInt();
      } catch (e) {
        print('評価システムからのレーティング取得エラー: $e');
      }
      
      setState(() {
        _partnerProfile = UserProfile(
          nickname: 'ずんだもん',
          gender: '回答しない',
          themeIndex: 0,
          rating: actualRating,
        );
        _isLoading = false;
        _partnerRating = actualRating;
      });
      
      // レートアニメーションを更新
      _rateController.reset();
      _rateAnimation = IntTween(begin: 0, end: _partnerRating).animate(
        CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
      );
      _rateController.forward();
    }
  }

  Future<UserProfile?> _getPartnerProfile(String partnerId) async {
    try {
      // UserProfileServiceを使用して統一されたプロフィール取得
      final doc = await FirebaseFirestore.instance.collection('userProfiles').doc(partnerId).get();
      if (doc.exists) {
        final profile = UserProfile.fromMap(doc.data()!);
        
        // レーティングが1000（デフォルト）の場合、評価システムから最新値を取得
        if (profile.rating == 1000) {
          try {
            final evaluationService = EvaluationService();
            final actualRating = await evaluationService.getUserRating(partnerId);
            
            return profile.copyWith(rating: actualRating.toInt());
          } catch (e) {
            print('評価システムからのレーティング取得エラー: $e');
            return profile;
          }
        }
        
        return profile;
      }
      return null;
    } catch (e) {
      print('パートナープロフィール取得エラー: $e');
      return null;
    }
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await _profileService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _myProfile = profile;
          _myIconPath = profile.iconPath ?? 'aseets/icons/Woman 1.svg';
          // マッチング時の表示コメントは固定
          _userComment = 'よろしくお願いします！';
          // _userComment = profile.comment?.isNotEmpty == true 
          //     ? (profile.comment!.length > 20 
          //         ? profile.comment!.substring(0, 20) + '...' 
          //         : profile.comment!) 
          //     : 'よろしくお願いします！';
        });
      }
    } catch (e) {
      print('自分のプロフィール読み込みエラー: $e');
    }
  }

  Future<void> _saveDefaultProfileForUser(String userId, UserProfile profile) async {
    try {
      await FirebaseFirestore.instance.collection('userProfiles').doc(userId).set(
        profile.toMap(),
        SetOptions(merge: true),
      );
      print('デフォルトプロフィール保存成功: $userId');
    } catch (e) {
      print('デフォルトプロフィール保存エラー: $e');
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 背景アニメーション
          _buildBackground(),
          // メインコンテンツ
          _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3A8A).withOpacity(0.8),
              const Color(0xFF7C3AED).withOpacity(0.8),
              const Color(0xFFEC4899).withOpacity(0.8),
            ],
          ),
        ),
        child: Lottie.asset(
          _backgroundAnimations[_currentBackgroundIndex],
          fit: _backgroundFits[_currentBackgroundIndex],
          alignment: _backgroundAlignments[_currentBackgroundIndex],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // ヘッダー部分
            _buildHeader(),
            const SizedBox(height: 40),
            
            // アイコンとプロフィール
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // アイコンアニメーション
                  _buildIconSection(),
                  const SizedBox(height: 40),
                  
                  // プロフィール情報
                  _buildProfileInfo(),
                  const SizedBox(height: 40),
                  
                  // コメント（10px上に移動）
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: _buildCommentSection(),
                  ),
                ],
              ),
            ),
            
            // フッター（レートカウンター）
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Talk One',
          style: GoogleFonts.caveat(
            fontSize: 40,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Text(
            _backgroundNames[_currentBackgroundIndex],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconSection() {
    return SlideTransition(
      position: _bubbleAnimation,
      child: AnimatedBuilder(
        animation: _waveAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _waveAnimation.value,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: SvgPicture.asset(
                    _partnerProfile?.iconPath ?? 'aseets/icons/Guy 1.svg',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfo() {
    if (_isLoading) {
      return const Column(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'プロフィールを読み込み中...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // ニックネーム
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'ニックネーム',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _partnerProfile?.nickname ?? 'ずんだもん',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // 性別
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                '性別',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _partnerProfile?.gender ?? '回答しない',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        _userComment,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFooter() {
    return SizedBox(
      width: 100,
      height: 90,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RATE',
            style: GoogleFonts.catamaran(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _rateAnimation,
            builder: (context, child) => Text(
              '${_rateAnimation.value}',
              style: GoogleFonts.notoSans(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}