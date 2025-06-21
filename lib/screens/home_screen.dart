import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'matching_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _bubbleController;
  late Animation<Offset> _bubbleAnimation;
  late AnimationController _rateController;
  late Animation<int> _rateAnimation;

  final UserProfileService _userProfileService = UserProfileService();
  int _userRating = 1000;

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

  // AIアイコンのSVGパス
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  final List<String> _svgIcons = [
    'aseets/icons/Guy 1.svg',
    'aseets/icons/Guy 2.svg',
    'aseets/icons/Guy 3.svg',
    'aseets/icons/Guy 4.svg',
    'aseets/icons/Woman 1.svg',
    'aseets/icons/Woman 2.svg',
    'aseets/icons/Woman 3.svg',
    'aseets/icons/Woman 4.svg',
    'aseets/icons/Woman 5.svg',
  ];

  // HomeScreenのStateにテーマインデックスを追加
  int _selectedThemeIndex = 0;

  // コメント候補リストを追加
  final List<String> _randomComments = [
    'こんにちは〜。今日もがんばってるね！',
    'おつかれさま。ひといきつこ〜',
    '今日はどんなアイディアが浮かんでる？',
    'ご主人、AIが遊びたがっております〜！',
  ];
  late String _selectedComment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserRating();
    
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
      begin: const Offset(0, 0),
      end: const Offset(0, -0.1),
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeInOut,
    ));

    _rateController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rateAnimation = IntTween(
      begin: 0,
      end: _userRating,
    ).animate(CurvedAnimation(
      parent: _rateController,
      curve: Curves.easeOut,
    ));

    _rateController.forward();
    _selectedComment = (_randomComments..shuffle()).first;
  }

  Future<void> _loadUserRating() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _userRating = profile.rating;
        _rateAnimation = IntTween(
          begin: 0,
          end: _userRating,
        ).animate(CurvedAnimation(
          parent: _rateController,
          curve: Curves.easeOut,
        ));
        // アイコンパスとテーマインデックスも更新
        if (profile.iconPath != null) {
          _selectedIconPath = profile.iconPath;
        }
        _selectedThemeIndex = profile.themeIndex;
      });
      _rateController.reset();
      _rateController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveController.dispose();
    _bubbleController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  // 画面復帰時にレーティングを更新
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadUserRating();
    }
  }

  // ウィジェットツリー復帰時にレーティングを更新  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 他の画面から戻ってきた時にレーティングを更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserRating();
    });
  }

  // 背景を切り替えるメソッド
  void _switchBackground() {
    setState(() {
      _currentBackgroundIndex =
          (_currentBackgroundIndex + 1) % _backgroundAnimations.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppThemePalette theme = appThemes[_selectedThemeIndex];
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          SafeArea(child: Center(child: _buildContent(context, theme))),
          // 下部バー
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Platform.isAndroid
                ? SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    bottom: true,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.barColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: SvgPicture.asset('aseets/icons/ber_Icon.svg',
                                width: 32, height: 32),
                            onPressed: () {
                              Navigator.of(context).push(_createHistoryRoute());
                            },
                          ),
                          const SizedBox(width: 64),
                          IconButton(
                            icon: SvgPicture.asset('aseets/icons/bell.svg',
                                width: 36, height: 36),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(_createNotificationRoute());
                            },
                          ),
                          const SizedBox(width: 64),
                          IconButton(
                            icon: SvgPicture.asset('aseets/icons/Settings.svg',
                                width: 29, height: 29),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(_createSettingsRoute());
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.barColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: SvgPicture.asset('aseets/icons/ber_Icon.svg',
                              width: 32, height: 32),
                          onPressed: () {
                            Navigator.of(context).push(_createHistoryRoute());
                          },
                        ),
                        const SizedBox(width: 64),
                        IconButton(
                          icon: SvgPicture.asset('aseets/icons/bell.svg',
                              width: 36, height: 36),
                          onPressed: () {
                            Navigator.of(context)
                                .push(_createNotificationRoute());
                          },
                        ),
                        const SizedBox(width: 64),
                        IconButton(
                          icon: SvgPicture.asset('aseets/icons/Settings.svg',
                              width: 29, height: 29),
                          onPressed: () {
                            Navigator.of(context).push(_createSettingsRoute());
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppThemePalette theme) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Column(
      children: [
        const SizedBox(height: 40),
        _buildTitle(),
        SizedBox(height: screenHeight * 0.20),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildAiIcon(),
              // 編集ボタンをAIアイコンの右下に重ねる
              Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: FloatingActionButton(
                    backgroundColor: const Color(0xFFAD98E1),
                    onPressed: _showIconSelectDialog,
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 18),
                    elevation: 2,
                  ),
                ),
              ),
              Positioned(
                top: -110,
                right: -160,
                child: _buildSpeechBubble(),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.05),
        _buildAICallButton(theme),
        const SizedBox(height: 16),
        _buildRateCounter(),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      'Talk One',
      style: GoogleFonts.caveat(
        fontSize: 60,
        color: const Color(0xFF4E3B7A),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return SlideTransition(
      position: _bubbleAnimation,
      child: Container(
        width: 220,
        height: 110,
        child: Stack(
          children: [
            // メッセージ部分
            Positioned(
              left: 3,
              top: 8,
              child: Container(
                width: 168,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _selectedComment,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Cascadia Mono',
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // 雲の部分（上）
            Positioned(
              left: 24,
              top: 63,
              child: Container(
                width: 37,
                height: 19,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            // 雲の部分（下）
            Positioned(
              left: 24,
              top: 87,
              child: Container(
                width: 24,
                height: 19,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiIcon() {
    return Container(
      width: 120, // 100から120に拡大（1.2倍）
      height: 120, // 100から120に拡大（1.2倍）
      decoration: const BoxDecoration(
        color: Color(0xFFE2E0F9),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          _selectedIconPath!,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildRateCounter() {
    return Container(
      width: 130, // 幅を100から130に拡大
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

  Widget _buildAICallButton(AppThemePalette theme) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MatchingScreen(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.callIconColor,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      child: const Icon(
        Icons.phone,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  // アイコン選択ダイアログ
  void _showIconSelectDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アイコンを選択'),
          content: SizedBox(
            width: 300,
            height: 200,
            child: GridView.count(
              crossAxisCount: 3,
              children: _svgIcons.map((iconPath) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(iconPath),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(iconPath),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _selectedIconPath = selected;
      });
      // アイコンをFirebaseに保存
      await _userProfileService.updateIconPath(selected);
    }
  }

  // 設定画面へのスライド遷移
  Route _createSettingsRoute() {
    final theme = appThemes[_selectedThemeIndex];
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
        currentThemeIndex: _selectedThemeIndex,
        onThemeChanged: (int newIndex) async {
          setState(() {
            _selectedThemeIndex = newIndex;
          });
          // テーマをFirebaseに保存
          await _userProfileService.updateThemeIndex(newIndex);
        },
        theme: theme,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // 履歴画面へのスライド遷移
  Route _createHistoryRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const HistoryScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // 通知画面へのスライド遷移
  Route _createNotificationRoute() {
    final theme = appThemes[_selectedThemeIndex];
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          NotificationScreen(theme: theme),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, -1.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}

// 設定画面本体
class SettingsScreen extends StatelessWidget {
  final int currentThemeIndex;
  final void Function(int) onThemeChanged;
  final AppThemePalette theme;
  const SettingsScreen(
      {super.key,
      required this.currentThemeIndex,
      required this.onThemeChanged,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '設定',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 48), // アイコン分のスペース
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.white),
                  title: const Text('プロフィール設定',
                      style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.white),
                  title: const Text('クレジット表記',
                      style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => CreditScreen(theme: theme)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.color_lens, color: Colors.white),
                  title: const Text('背景テーマ',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Row(
                    children: List.generate(
                        appThemes.length,
                        (i) => GestureDetector(
                              onTap: () {
                                onThemeChanged(i);
                                Navigator.pop(context);
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: appThemes[i].backgroundColor,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: currentThemeIndex == i
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 20)
                                    : null,
                              ),
                            )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// プロフィール設定画面
class ProfileSettingScreen extends StatelessWidget {
  final AppThemePalette theme;
  const ProfileSettingScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'プロフィール設定',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 48),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'あなたのプロフィール',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ニックネーム
                    _ProfileInputField(
                      hintText: 'ニックネーム',
                      inputType: TextInputType.text,
                    ),
                    const SizedBox(height: 20),
                    // 性別（選択式の丸みを帯びた四角）
                    _ProfileSelectBox(
                      hintText: '性別',
                      child: _GenderDropdown(),
                    ),
                    const SizedBox(height: 20),
                    // 誕生日
                    _ProfileSelectBox(
                      hintText: '誕生日',
                      child: _BirthdayField(),
                    ),
                    const SizedBox(height: 20),
                    // AIに覚えておいてほしいこと
                    _ProfileInputField(
                      hintText: 'AIに覚えておいてほしいこと',
                      inputType: TextInputType.multiline,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF979CDE),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                        ),
                        onPressed: () {},
                        child: const Text('保存'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 通報ボタン
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE05E37),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('通報'),
                              content: const Text('通報が送信されました。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('通報'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 共通：丸みを帯びた四角の入力欄
class _ProfileInputField extends StatelessWidget {
  final String hintText;
  final TextInputType inputType;
  final int maxLines;
  const _ProfileInputField({
    required this.hintText,
    required this.inputType,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        keyboardType: inputType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
              color: Color(0xFF4E3B7A), fontWeight: FontWeight.bold),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// 共通：丸みを帯びた四角の選択ボックス
class _ProfileSelectBox extends StatelessWidget {
  final String hintText;
  final Widget child;
  const _ProfileSelectBox({required this.hintText, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              hintText,
              style: const TextStyle(
                  color: Color(0xFF4E3B7A), fontWeight: FontWeight.bold),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// 性別選択（ドロップダウン式、透明度のある白背景）
class _GenderDropdown extends StatefulWidget {
  @override
  State<_GenderDropdown> createState() => _GenderDropdownState();
}

class _GenderDropdownState extends State<_GenderDropdown> {
  String? _selected;
  final List<String> _genders = ['男性', '女性', '回答しない'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selected,
          hint: const Text('選択してください',
              style: TextStyle(
                  color: Color(0xFF4E3B7A), fontWeight: FontWeight.bold)),
          isExpanded: true,
          dropdownColor: Colors.white.withOpacity(0.9),
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          borderRadius: BorderRadius.circular(12),
          items: _genders
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selected = v),
        ),
      ),
    );
  }
}

// 誕生日入力ウィジェット
class _BirthdayField extends StatefulWidget {
  @override
  State<_BirthdayField> createState() => _BirthdayFieldState();
}

class _BirthdayFieldState extends State<_BirthdayField> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000, 1, 1),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF979CDE),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF5A64ED),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _selectedDate == null
              ? '選択してください'
              : '${_selectedDate!.year}年${_selectedDate!.month}月${_selectedDate!.day}日',
          style: const TextStyle(color: Color(0xFF5A64ED), fontSize: 16),
        ),
      ),
    );
  }
}

// クレジット表記画面
class CreditScreen extends StatelessWidget {
  final AppThemePalette theme;
  const CreditScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'クレジット表記',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 48),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TalkOneタイトル
                    Center(
                      child: Text(
                        'Talk One',
                        style: GoogleFonts.caveat(
                          fontSize: 60,
                          color: const Color(0xFF4E3B7A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 謝辞タイトル（左寄せ）
                    const Text(
                      '謝辞',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 16),
                    // 謝辞内容（F9F2F2の丸みを帯びた四角、黒文字）
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFFF9F2F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'VOICEVOX  …  © Hiroshiba Kazuyuki\n'
                        'Fluent Emoji  …  © Microsoft\n'
                        'Lottiefiles\n'
                        '　Free Cold Mountain Background Animation\n'
                        '　© Felipe Da Silva Pinho\n'
                        'Figma\n'
                        '　People Icons\n'
                        '　© Terra Pappas\n'
                        '\n'
                        'MIT License\n'
                        'Copyright (c)  yuu-1230, truemato\n'
                        '\n'
                        'Permission is hereby granted, free of charge, to any person obtaining a copy\n'
                        'of this software and associated documentation files (the "Software"), to deal\n'
                        'in the Software without restriction, including without limitation the rights\n'
                        'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n'
                        'copies of the Software, and to permit persons to whom the Software is\n'
                        'furnished to do so, subject to the following conditions:\n'
                        '　The above copyright notice and this permission notice shall be included in\n'
                        '　all copies or substantial portions of the Software.\n'
                        '\n'
                        'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n'
                        'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
                        'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n'
                        'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n'
                        'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n'
                        'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n'
                        'SOFTWARE.',
                        style: TextStyle(
                            color: Colors.black, fontSize: 14, height: 1.7),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// 通知画面（仮）
class NotificationScreen extends StatelessWidget {
  final AppThemePalette theme;
  const NotificationScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '通知',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 48),
            ],
          ),
          const Expanded(
            child: Center(
              child: Text('通知画面（仮）', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// テーマ用データクラス（matching_screen.dartから重複移動）
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

// パレット一覧（matching_screen.dartから重複移動）
const List<AppThemePalette> appThemes = [
  // 1. デフォルト
  AppThemePalette(
    backgroundColor: Color(0xFF5A64ED),
    barColor: Color(0xFF979CDE),
    callIconColor: Color(0xFF4CAF50),
  ),
  // 2. E6D283, EAC77A, F59A3E
  AppThemePalette(
    backgroundColor: Color(0xFFE6D283),
    barColor: Color(0xFFEAC77A),
    callIconColor: Color(0xFFF59A3E),
  ),
  // 3. A482E5, D7B3E8, D487E6
  AppThemePalette(
    backgroundColor: Color(0xFFA482E5),
    barColor: Color(0xFFD7B3E8),
    callIconColor: Color(0xFFD487E6),
  ),
  // 4. 83C8E6, B8D8E6, 618DAA
  AppThemePalette(
    backgroundColor: Color(0xFF83C8E6),
    barColor: Color(0xFFB8D8E6),
    callIconColor: Color(0xFF618DAA),
  ),
  // 5. F0941F, EF6024, 548AB6
  AppThemePalette(
    backgroundColor: Color(0xFFF0941F),
    barColor: Color(0xFFEF6024),
    callIconColor: Color(0xFF548AB6),
  ),
];