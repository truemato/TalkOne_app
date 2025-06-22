import * as functions from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { Logging } from '@google-cloud/logging';
// import { google } from 'googleapis'; // Gmail API は複雑なため一時的にコメントアウト

// Firebase Admin の初期化
admin.initializeApp();

// Cloud Logging クライアントの初期化
const logging = new Logging();
const log = logging.log('talkone-reports');

// Gmail API 設定
const ADMIN_EMAIL = 'serveman520@gmail.com';

/**
 * 簡易通知送信（Gmail API の代替）
 */
async function sendSimpleNotification(reportData: any, reporterInfo: any, reportedInfo: any, reportId: string): Promise<void> {
  try {
    // 1. 重要度の高いログを出力（管理者が確認しやすいように）
    console.error('🚨 URGENT REPORT ALERT 🚨', {
      reportId,
      reason: reportData.reason,
      reporterUid: reportData.reporterUid,
      reportedUid: reportData.reportedUid,
      timestamp: new Date().toISOString()
    });
    
    // 2. Firestore に緊急通知フラグを立てる
    await admin.firestore()
      .collection('adminNotifications')
      .add({
        type: 'URGENT_REPORT',
        title: `🚨 通報アラート: ${reportData.reason}`,
        message: `ユーザー ${reportData.reporterUid} が ${reportData.reportedUid} を通報しました。`,
        reportId,
        priority: 'HIGH',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        data: {
          reportData,
          reporterInfo,
          reportedInfo
        }
      });
    
    // 3. コンソールに詳細情報を出力
    console.log('='.repeat(80));
    console.log('🚨 TALKONE 通報アラート 🚨');
    console.log(`管理者: ${ADMIN_EMAIL}`);
    console.log('='.repeat(80));
    console.log(`通報理由: ${reportData.reason}`);
    console.log(`詳細: ${reportData.detail || 'なし'}`);
    console.log(`通報者: ${(reporterInfo as any).nickname} (${reportData.reporterUid})`);
    console.log(`被通報者: ${(reportedInfo as any).nickname} (${reportData.reportedUid})`);
    console.log(`Call ID: ${reportData.callId}`);
    console.log(`日時: ${new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })}`);
    console.log('Firebase Console:', `https://console.firebase.google.com/project/${process.env.GCP_PROJECT}/firestore/data/~2Freports~2F${reportId}`);
    console.log('='.repeat(80));
    
    console.log(`通報通知送信成功: ${ADMIN_EMAIL} (Cloud Logging)`);
  } catch (error) {
    console.error('通知送信エラー:', error);
    throw error;
  }
}

/**
 * 通報メール送信機能（Gmail API + Cloud Logging）
 * Firestore の reports コレクションに新しいドキュメントが追加されると実行される
 */
export const sendReportAlert = functions.onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const reportData = event.data?.data();
    
    if (!reportData) {
      console.error('通報データが見つかりません');
      return;
    }

    try {
      // 通報者と被通報者の情報を取得
      let reporterInfo = {};
      let reportedInfo = {};

      try {
        const reporterDoc = await admin.firestore()
          .collection('userProfiles')
          .doc(reportData.reporterUid)
          .get();
        
        if (reporterDoc.exists) {
          const reporterData = reporterDoc.data();
          reporterInfo = {
            nickname: reporterData?.nickname || '未設定',
            gender: reporterData?.gender || '未設定',
            rating: reporterData?.rating || 1000
          };
        }
      } catch (e) {
        console.warn('通報者情報の取得に失敗:', e);
        reporterInfo = { error: 'プロフィール情報の取得に失敗' };
      }

      try {
        const reportedDoc = await admin.firestore()
          .collection('userProfiles')
          .doc(reportData.reportedUid)
          .get();
        
        if (reportedDoc.exists) {
          const reportedData = reportedDoc.data();
          reportedInfo = {
            nickname: reportedData?.nickname || '未設定',
            gender: reportedData?.gender || '未設定',
            rating: reportedData?.rating || 1000
          };
        }
      } catch (e) {
        console.warn('被通報者情報の取得に失敗:', e);
        reportedInfo = { error: 'プロフィール情報の取得に失敗' };
      }

      // 構造化ログとして Cloud Logging に出力（重要度: ERROR）
      const logEntry = log.entry({
        severity: 'ERROR',
        resource: { type: 'cloud_function' },
        labels: {
          function_name: 'logReportAlert',
          report_type: 'user_report'
        }
      }, {
        message: '🚨 TalkOne 新規通報アラート',
        reportId: event.document.split('/').pop(),
        timestamp: new Date().toISOString(),
        report: {
          reason: reportData.reason,
          detail: reportData.detail || null,
          callId: reportData.callId,
          isDummyMatch: reportData.isDummyMatch,
          status: reportData.status || 'pending'
        },
        reporter: {
          uid: reportData.reporterUid,
          email: reportData.reporterEmail || null,
          ...reporterInfo
        },
        reported: {
          uid: reportData.reportedUid,
          ...reportedInfo
        },
        links: {
          firebaseConsole: `https://console.firebase.google.com/project/${process.env.GCP_PROJECT}/firestore/data/~2Freports~2F${event.document.split('/').pop()}`,
          cloudLogging: `https://console.cloud.google.com/logs/query;query=labels.report_type%3D%22user_report%22?project=${process.env.GCP_PROJECT}`
        }
      });

      await log.write(logEntry);
      
      // 簡易通知送信
      await sendSimpleNotification(reportData, reporterInfo, reportedInfo, event.document.split('/').pop()!);
      
      console.log(`通報アラート送信成功: Report ID ${event.document.split('/').pop()}`);
      
      // Firestore の通報ドキュメントに送信完了フラグを追加
      await admin.firestore()
        .collection('reports')
        .doc(event.document.split('/').pop()!)
        .update({
          alertSent: true,
          alertSentAt: admin.firestore.FieldValue.serverTimestamp(),
          alertType: 'cloud_logging',
          notificationSent: true,
          notificationSentAt: admin.firestore.FieldValue.serverTimestamp()
        });

    } catch (error) {
      console.error('通報アラート送信エラー:', error);
      
      // エラー情報を Firestore に記録
      await admin.firestore()
        .collection('reports')
        .doc(event.document.split('/').pop()!)
        .update({
          alertSent: false,
          alertError: error instanceof Error ? error.message : String(error),
          alertErrorAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
  }
);

/**
 * 通報統計情報を定期的に更新（オプション）
 */
export const updateReportStats = functions.onSchedule(
  '0 0 * * *', // 毎日午前0時に実行
  async () => {
    try {
      const today = new Date();
      const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);

      // 昨日の通報件数を集計
      const reportsSnapshot = await admin.firestore()
        .collection('reports')
        .where('createdAt', '>=', yesterday)
        .where('createdAt', '<', today)
        .get();

      const dailyStats = {
        date: yesterday.toISOString().split('T')[0],
        totalReports: reportsSnapshot.size,
        pendingReports: reportsSnapshot.docs.filter(doc => 
          doc.data().status === 'pending'
        ).length,
        processedReports: reportsSnapshot.docs.filter(doc => 
          doc.data().status !== 'pending'
        ).length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // 統計情報を保存
      await admin.firestore()
        .collection('reportStats')
        .doc(dailyStats.date)
        .set(dailyStats);

      console.log(`通報統計情報を更新しました: ${dailyStats.date}`);
    } catch (error) {
      console.error('通報統計情報の更新エラー:', error);
    }
  }
);