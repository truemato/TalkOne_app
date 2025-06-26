import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Androidでのテスト用設定
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  // 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Googleアカウントでサインイン
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('=== Google Sign In Debug Start ===');
      print('Google Sign In開始');
      print('GoogleSignIn設定: ${_googleSignIn.toString()}');
      
      // Google Play Services の可用性を確認
      try {
        final isAvailable = await _googleSignIn.isSignedIn();
        print('Google Sign In Service 状態: $isAvailable');
      } catch (e) {
        print('Google Sign In Service 確認エラー: $e');
      }
      
      // Google認証フローを開始
      print('Google認証フロー開始...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Googleサインインがキャンセルされました');
        print('考えられる原因:');
        print('1. ユーザーがキャンセルボタンを押した');
        print('2. Google Play Services が利用できない');
        print('3. OAuth設定が正しくない');
        print('4. エミュレーターにGoogleアカウントが設定されていない');
        return null;
      }

      print('✅ Google認証成功: ${googleUser.email}');
      print('ユーザーID: ${googleUser.id}');
      print('表示名: ${googleUser.displayName}');

      // Google認証の詳細を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebaseにサインイン
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // 新規ユーザーの場合、プロフィールを初期化
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await _initializeUserProfile(userCredential.user!);
      }

      print('✅ Firebase認証成功: ${userCredential.user?.uid}');
      print('=== Google Sign In Debug End ===');
      return userCredential;
    } catch (e) {
      print('❌ Google Sign Inエラー: $e');
      print('エラータイプ: ${e.runtimeType}');
      if (e.toString().contains('DEVELOPER_ERROR')) {
        print('🔧 DEVELOPER_ERROR: SHA-1フィンガープリントまたはOAuth設定を確認してください');
      } else if (e.toString().contains('SIGN_IN_CANCELLED')) {
        print('👤 SIGN_IN_CANCELLED: ユーザーがサインインをキャンセルしました');
      } else if (e.toString().contains('SIGN_IN_FAILED')) {
        print('⚠️ SIGN_IN_FAILED: Google Play Servicesの問題の可能性があります');
      }
      print('=== Google Sign In Debug End ===');
      return null;
    }
  }

  // 匿名認証でサインイン
  Future<UserCredential?> signInAnonymously() async {
    try {
      print('匿名認証開始');
      final UserCredential userCredential = await _auth.signInAnonymously();
      
      // 匿名ユーザーのプロフィールを初期化
      await _initializeUserProfile(userCredential.user!);
      
      print('匿名認証成功: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      print('匿名認証エラー: $e');
      return null;
    }
  }

  // 匿名アカウントをGoogleアカウントにリンク
  Future<UserCredential?> linkAnonymousWithGoogle() async {
    try {
      if (currentUser == null || !currentUser!.isAnonymous) {
        print('匿名ユーザーではありません');
        return null;
      }

      print('匿名アカウントをGoogleアカウントにリンク開始');

      // Google認証フローを開始
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Googleサインインがキャンセルされました');
        return null;
      }

      // Google認証の詳細を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase認証用のクレデンシャルを作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 匿名アカウントにGoogleアカウントをリンク
      final UserCredential userCredential = await currentUser!.linkWithCredential(credential);
      
      print('アカウントリンク成功: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      print('アカウントリンクエラー: $e');
      
      // 既に同じメールアドレスでアカウントが存在する場合の処理
      if (e is FirebaseAuthException && e.code == 'credential-already-in-use') {
        print('既存のGoogleアカウントに移行します');
        return await signInWithGoogle();
      }
      
      return null;
    }
  }

  // サインアウト
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('サインアウト成功');
    } catch (e) {
      print('サインアウトエラー: $e');
    }
  }

  // ユーザープロフィールを初期化
  Future<void> _initializeUserProfile(User user) async {
    try {
      final userDoc = _firestore.collection('userProfiles').doc(user.uid);
      final docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        // Googleアカウントの場合は表示名とメールを使用
        final nickname = user.displayName ?? 'ユーザー${user.uid.substring(0, 6)}';
        
        await userDoc.set({
          'nickname': nickname,
          'email': user.email,
          'iconPath': 'aseets/icons/Woman 1.svg',
          'gender': '回答しない',
          'comment': 'よろしくお願いします！',
          'aiMemory': '',
          'themeIndex': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isAnonymous': user.isAnonymous,
        });

        // レーティング初期化
        await _firestore.collection('userRatings').doc(user.uid).set({
          'rating': 1000, // 初期レーティング
          'totalGames': 0,
          'winStreak': 0,
          'maxWinStreak': 0,
          'lastGameAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('ユーザープロフィール初期化完了: ${user.uid}');
      }
    } catch (e) {
      print('プロフィール初期化エラー: $e');
    }
  }

  // 匿名ユーザーかどうかを確認
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // サインイン済みかどうかを確認
  bool get isSignedIn => currentUser != null;

  // Googleアカウントでサインイン済みかどうかを確認
  bool get isGoogleSignedIn => currentUser != null && !currentUser!.isAnonymous && currentUser!.email != null;
}