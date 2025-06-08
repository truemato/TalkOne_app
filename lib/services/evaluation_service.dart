// lib/services/evaluation_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EvaluationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // 評価を送信する
  Future<void> submitEvaluation({
    required String callId,
    required String partnerId,
    required int rating, // 1-5
    String? comment,
    bool isDummyMatch = false,
  }) async {
    try {
      // 評価データを保存
      await _db.collection('evaluations').add({
        'callId': callId,
        'evaluatorId': _userId,
        'evaluatedUserId': partnerId,
        'rating': rating,
        'comment': comment ?? '',
        'isDummyMatch': isDummyMatch,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ダミーマッチでない場合のみレーティングを更新
      if (!isDummyMatch) {
        await _updateUserRating(partnerId, rating);
        await _updateUserRating(_userId, 0); // 自分の参加回数も更新
      } else {
        // ダミーマッチ（AI通話）の場合、自分に+1ポイント、参加回数も更新
        await _updateUserRating(_userId, 3); // 星3相当（+1ポイント）を自分に付与
      }

      print('評価送信完了: $rating stars for $partnerId');
    } catch (e) {
      print('評価送信エラー: $e');
      rethrow;
    }
  }

  // ユーザーのレーティングを更新
  Future<void> _updateUserRating(String userId, int rating) async {
    final userRef = _db.collection('users').doc(userId);
    
    await _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final currentRating = (data['rating'] ?? 1000.0).toDouble();
        final totalCalls = (data['totalCalls'] ?? 0) + 1;
        final totalRatingReceived = (data['totalRatingReceived'] ?? 0.0) + rating;
        
        // 新しい平均レーティングを計算
        double newRating = currentRating;
        if (rating > 0) { // 評価を受けた場合のみ
          newRating = _calculateNewRating(currentRating, rating, totalCalls);
        }

        transaction.update(userRef, {
          'rating': newRating,
          'totalCalls': totalCalls,
          'totalRatingReceived': totalRatingReceived,
          'lastCallAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 初回ユーザー作成
        transaction.set(userRef, {
          'userId': userId,
          'rating': rating > 0 ? _calculateInitialRating(rating) : 100.0,
          'totalCalls': 1,
          'totalRatingReceived': rating.toDouble(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastCallAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // レーティング計算（初期値100、最大999、星3で+1、星4で+2、星5で+3）
  double _calculateNewRating(double currentRating, int receivedRating, int totalCalls) {
    int ratingDelta = 0;
    
    switch (receivedRating) {
      case 1:
        ratingDelta = -2; // 星1で-2
        break;
      case 2:
        ratingDelta = -1; // 星2で-1
        break;
      case 3:
        ratingDelta = 1;  // 星3で+1
        break;
      case 4:
        ratingDelta = 2;  // 星4で+2
        break;
      case 5:
        ratingDelta = 3;  // 星5で+3
        break;
      default:
        ratingDelta = 0;
    }
    
    // 新しいレーティング = 現在のレーティング + 差分
    final newRating = currentRating + ratingDelta;
    
    // 範囲制限（0-999）
    return newRating.clamp(0.0, 999.0);
  }

  // 初回レーティング計算（初期値100）
  double _calculateInitialRating(int firstRating) {
    // 初期値100から開始
    const double initialRating = 100.0;
    
    int ratingDelta = 0;
    switch (firstRating) {
      case 1:
        ratingDelta = -2;
        break;
      case 2:
        ratingDelta = -1;
        break;
      case 3:
        ratingDelta = 1;
        break;
      case 4:
        ratingDelta = 2;
        break;
      case 5:
        ratingDelta = 3;
        break;
      default:
        ratingDelta = 0;
    }
    
    return (initialRating + ratingDelta).clamp(0.0, 999.0);
  }

  // ユーザーの現在のレーティングを取得
  Future<double> getUserRating([String? userId]) async {
    final targetUserId = userId ?? _userId;
    final userDoc = await _db.collection('users').doc(targetUserId).get();
    
    if (userDoc.exists) {
      return (userDoc.data()?['rating'] ?? 100.0).toDouble();
    }
    return 100.0; // デフォルトレーティング（初期値100）
  }

  // 評価履歴を取得
  Future<List<Map<String, dynamic>>> getEvaluationHistory() async {
    final evaluations = await _db
        .collection('evaluations')
        .where('evaluatedUserId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return evaluations.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // レーティング帯に基づくマッチング推奨
  Future<bool> shouldMatchWithAI(double userRating) async {
    // 90以下（100基準で-10以下）またはあまりにも低い評価が続いた場合
    if (userRating <= 90) {
      return true;
    }

    try {
      // 最近の評価が悪い場合もAIマッチングを推奨
      // インデックスが不要なシンプルなクエリに変更
      final recentEvaluations = await _db
          .collection('evaluations')
          .where('evaluatedUserId', isEqualTo: _userId)
          .limit(20)  // orderByを削除し、クライアント側でソート
          .get();

      if (recentEvaluations.docs.length >= 3) {
        // クライアント側で日付順にソート
        final sortedDocs = recentEvaluations.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);  // 降順
          });
        
        // 最新の5件を取得
        final recent5 = sortedDocs.take(5).toList();
        
        if (recent5.length >= 3) {
          final recentRatings = recent5
              .map((doc) => (doc.data()['rating'] as int))
              .toList();
          
          final averageRecentRating = recentRatings.reduce((a, b) => a + b) / recentRatings.length;
          
          // 最近の平均が2.5以下ならAI練習を推奨
          return averageRecentRating <= 2.5;
        }
      }
    } catch (e) {
      print('評価履歴取得エラー: $e');
      // エラー時はレーティングのみで判断
    }

    return false;
  }
}