// lib/utils/permission_util.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionUtil {
  static const _firstLaunchKey = 'is_first_launch_done';

  /// 初回ならカメラ & マイク & 音声認識をリクエストして true を返す。
  /// 2 回目以降は何もしない。
  static Future<bool> handleFirstLaunchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final isDone = prefs.getBool(_firstLaunchKey) ?? false;
    print('PermissionUtil: 初回起動チェック - isDone: $isDone');
    
    if (isDone) {
      print('PermissionUtil: 既に権限リクエスト済み、スキップします');
      return true;
    }

    // ★ 必要な権限をまとめてリクエスト
    print('PermissionUtil: 権限リクエストを開始します');
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.speech,  // iOS音声認識用
      // Permission.notification, // ← 通知も必要なら追加
    ].request();
    
    print('PermissionUtil: 権限リクエスト結果: $statuses');

    // いずれかが permanentlyDenied なら設定画面へ誘導してもよい
    final allGranted = statuses.values.every((st) => st.isGranted);

    // 1 回実行したらフラグを立てる（成功・失敗どちらでも）
    await prefs.setBool(_firstLaunchKey, true);
    return allGranted;
  }
  
  /// 権限の状態を確認（リクエストはしない）
  static Future<Map<Permission, PermissionStatus>> checkPermissionStatuses() async {
    final Map<Permission, PermissionStatus> statuses = {};
    statuses[Permission.camera] = await Permission.camera.status;
    statuses[Permission.microphone] = await Permission.microphone.status;
    statuses[Permission.speech] = await Permission.speech.status;
    return statuses;
  }
  
  /// 特定の権限が許可されているか確認
  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }
  
  /// デバッグ用：初回起動フラグをリセット
  static Future<void> resetFirstLaunchFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
    print('PermissionUtil: 初回起動フラグをリセットしました');
  }
}