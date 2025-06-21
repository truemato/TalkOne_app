import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 縦向き固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 匿名認証を自動で実行
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    
    // 権限の初期確認（必須権限のみ）
    await _checkInitialPermissions();
    
    runApp(const MyApp());
  } catch (e) {
    print('Firebase初期化エラー: $e');
    runApp(ErrorApp(message: 'アプリの初期化に失敗しました: $e'));
  }
}

// 初期権限確認
Future<void> _checkInitialPermissions() async {
  try {
    print('アプリ起動: 権限確認開始');
    
    // マイク権限の確認
    final micStatus = await Permission.microphone.status;
    print('マイク権限状態: $micStatus');
    
    if (micStatus == PermissionStatus.denied) {
      print('マイク権限を要求中...');
      final result = await Permission.microphone.request();
      print('マイク権限要求結果: $result');
    }
    
    // カメラ権限の確認（先にチェックのみ）
    final cameraStatus = await Permission.camera.status;
    print('カメラ権限状態: $cameraStatus');
    
    print('権限確認完了');
  } catch (e) {
    print('権限確認エラー: $e');
    // エラーがあってもアプリは起動する
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const HomeScreen(),
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