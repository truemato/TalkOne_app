import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallHistory {
  final String callId;
  final String partnerId;
  final String partnerNickname;
  final String partnerIconPath;
  final DateTime callDateTime;
  final int callDuration; // 秒数
  final bool isAiCall;
  final int? myRatingToPartner; // 相手への評価
  final int? partnerRatingToMe; // 相手からの評価

  CallHistory({
    required this.callId,
    required this.partnerId,
    required this.partnerNickname,
    required this.partnerIconPath,
    required this.callDateTime,
    required this.callDuration,
    required this.isAiCall,
    this.myRatingToPartner,
    this.partnerRatingToMe,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'callId': callId,
      'partnerId': partnerId,
      'partnerNickname': partnerNickname,
      'partnerIconPath': partnerIconPath,
      'callDateTime': Timestamp.fromDate(callDateTime),
      'callDuration': callDuration,
      'isAiCall': isAiCall,
      'myRatingToPartner': myRatingToPartner,
      'partnerRatingToMe': partnerRatingToMe,
    };
  }

  factory CallHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallHistory(
      callId: data['callId'] ?? '',
      partnerId: data['partnerId'] ?? '',
      partnerNickname: data['partnerNickname'] ?? 'Unknown',
      partnerIconPath: data['partnerIconPath'] ?? 'aseets/icons/Woman 1.svg',
      callDateTime: (data['callDateTime'] as Timestamp).toDate(),
      callDuration: data['callDuration'] ?? 0,
      isAiCall: data['isAiCall'] ?? false,
      myRatingToPartner: data['myRatingToPartner'],
      partnerRatingToMe: data['partnerRatingToMe'],
    );
  }
}

class CallHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 通話履歴を保存
  Future<void> saveCallHistory(CallHistory history) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('callHistories')
          .doc(user.uid)
          .collection('calls')
          .add(history.toFirestore());
    } catch (e) {
      print('Error saving call history: $e');
    }
  }

  // 通話履歴を取得（最新順）
  Future<List<CallHistory>> getCallHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('callHistories')
          .doc(user.uid)
          .collection('calls')
          .orderBy('callDateTime', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => CallHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting call history: $e');
      return [];
    }
  }

  // 通話履歴をリアルタイムで取得
  Stream<List<CallHistory>> getCallHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('callHistories')
        .doc(user.uid)
        .collection('calls')
        .orderBy('callDateTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CallHistory.fromFirestore(doc))
          .toList();
    });
  }

  // 評価を後から更新
  Future<void> updateCallRating(String callId, int rating, bool isMyRating) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('callHistories')
          .doc(user.uid)
          .collection('calls')
          .where('callId', isEqualTo: callId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({
          isMyRating ? 'myRatingToPartner' : 'partnerRatingToMe': rating,
        });
      }
    } catch (e) {
      print('Error updating call rating: $e');
    }
  }
}