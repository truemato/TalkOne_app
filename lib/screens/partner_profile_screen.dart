import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/rating_service.dart';
import '../services/evaluation_service.dart';
import 'rematch_or_home_screen.dart';

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

class PartnerProfileScreen extends StatefulWidget {
  final String partnerId;
  final String callId;
  final bool isDummyMatch;

  const PartnerProfileScreen({
    super.key,
    required this.partnerId,
    required this.callId,
    this.isDummyMatch = false,
  });

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final RatingService _ratingService = RatingService();
  final EvaluationService _evaluationService = EvaluationService();
  
  // パートナー情報
  String? _partnerNickname = 'ずんだもん';
  String? _partnerGender = '回答しない';
  String? _partnerComment = 'よろしくお願いします！'; // ダミー
  String? _partnerIconPath = 'aseets/icons/Woman 1.svg';
  int _partnerThemeIndex = 0;
  
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
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartnerProfile();
  }

  Future<void> _loadPartnerProfile() async {
    try {
      // 相手の実際のプロフィールをFirebaseから取得
      final profile = await _userProfileService.getUserProfileById(widget.partnerId);
      
      if (profile != null && mounted) {
        setState(() {
          _partnerNickname = profile.nickname ?? 'ユーザー';
          _partnerGender = profile.gender ?? '未設定';
          _partnerComment = profile.aiMemory ?? 'よろしくお願いします！';
          _partnerIconPath = profile.iconPath ?? 'aseets/icons/Woman 1.svg';
          _partnerThemeIndex = profile.themeIndex ?? 0;
          // テーマインデックスが範囲外の場合はデフォルトに設定
          if (_partnerThemeIndex >= _appThemes.length) {
            _partnerThemeIndex = 0;
          }
          _isLoading = false;
        });
        print('相手のプロフィール読み込み完了: ${profile.nickname}');
      } else {
        // プロフィールが見つからない場合はデフォルト値を設定
        if (mounted) {
          setState(() {
            _partnerNickname = 'ユーザー';
            _partnerGender = '未設定';
            _partnerComment = 'よろしくお願いします！';
            _partnerIconPath = 'aseets/icons/Woman 1.svg';
            _partnerThemeIndex = 0;
            _isLoading = false;
          });
        }
        print('相手のプロフィールが見つかりません: ${widget.partnerId}');
      }
    } catch (e) {
      print('パートナープロフィール読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _partnerNickname = 'ユーザー';
          _partnerGender = '未設定';
          _partnerComment = 'よろしくお願いします！';
          _partnerIconPath = 'aseets/icons/Woman 1.svg';
          _partnerThemeIndex = 0;
          _isLoading = false;
        });
      }
    }
  }

  Color get _currentThemeColor => _appThemes[_partnerThemeIndex].backgroundColor;

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '通報',
          style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'このユーザーを通報しますか？',
          style: GoogleFonts.notoSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'キャンセル',
              style: GoogleFonts.notoSans(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _submitReportAndEvaluation();
            },
            child: Text(
              '通報する',
              style: GoogleFonts.notoSans(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReportAndEvaluation() async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );

      // 星1評価を自動送信
      await _evaluationService.submitEvaluation(
        callId: widget.callId,
        partnerId: widget.partnerId,
        rating: 1, // 星1
        comment: '通報により自動評価',
        isDummyMatch: widget.isDummyMatch,
      );

      // 相手のレーティングを更新（自分の値を参照しない、streakCountベース）
      await _ratingService.updateRating(1, widget.partnerId);

      // ローディングダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 通報完了メッセージを表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '通報を完了しました。',
              style: GoogleFonts.notoSans(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 1秒後にRematchOrHomeScreenに遷移
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const RematchOrHomeScreen(),
          ),
          (route) => false, // 全ての前の画面を削除
        );
      }
    } catch (e) {
      // エラー処理
      if (mounted) {
        // ローディングダイアログを閉じる
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '通報の送信に失敗しました: $e',
              style: GoogleFonts.notoSans(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _appThemes[_partnerThemeIndex];
    return Scaffold(
      backgroundColor: currentTheme.backgroundColor, // 相手のテーマカラーを使用
      body: Platform.isAndroid 
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Column(
      children: [
        // ヘッダー
        _buildHeader(),
        
        // コンテンツ
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // プロフィール画像
                _buildProfileIcon(),
                const SizedBox(height: 32),
                
                // ニックネーム
                _buildInfoField('ニックネーム', _partnerNickname ?? 'ユーザー'),
                const SizedBox(height: 20),
                
                // 性別
                _buildInfoField('性別', _partnerGender ?? '未設定'),
                const SizedBox(height: 20),
                
                // 一言コメント
                _buildInfoField('一言コメント', _partnerComment ?? 'よろしくお願いします！'),
                const SizedBox(height: 40),
                
                // 通報ボタン
                _buildReportButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                '相手のプロフィール',
                style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProfileIcon() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: SvgPicture.asset(
                _partnerIconPath!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _partnerNickname ?? 'ユーザー',
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            value,
            style: GoogleFonts.notoSans(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 4,
          ),
          onPressed: _showReportDialog,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.report, size: 24),
              const SizedBox(width: 8),
              Text(
                '通報',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}