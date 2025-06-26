import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/permission_denied_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/permission_util.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 環境変数を読み込み
  await dotenv.load(fileName: ".env");

  // 縦向き固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 初回起動時の権限処理
    print('main: 権限処理を開始します');

    // デバッグ：初回起動フラグをリセット（本番では削除）
    // await PermissionUtil.resetFirstLaunchFlag();

    final permissionGranted =
        await PermissionUtil.handleFirstLaunchPermissions();
    print('main: 権限処理結果 - permissionGranted: $permissionGranted');

    runApp(MyApp(permissionGranted: permissionGranted));
  } catch (e) {
    print('Firebase初期化エラー: $e');
    runApp(ErrorApp(message: 'アプリの初期化に失敗しました: $e'));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.permissionGranted});
  final bool permissionGranted;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: permissionGranted
          ? AuthWrapper() // 権限が許可されていれば認証チェック
          : const PermissionDeniedScreen(), // 権限が拒否されていれば案内画面へ
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // 認証状態の読み込み中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // ユーザーがサインイン済みの場合
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        
        // ユーザーがサインインしていない場合
        return const LoginScreen();
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;

  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'エラーが発生しました',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
