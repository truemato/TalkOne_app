# cloud_run/matching_service/main.py

import os
import json
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from google.cloud import firestore, tasks_v2
from google.auth import jwt
import numpy as np

app = Flask(__name__)

# 初期化
db = firestore.Client()
tasks_client = tasks_v2.CloudTasksClient()

# 環境変数
PROJECT_ID = os.environ.get('PROJECT_ID')
LOCATION = os.environ.get('LOCATION', 'asia-northeast1')
QUEUE_NAME = os.environ.get('QUEUE_NAME', 'matching-queue')

@app.route('/api/match/request', methods=['POST'])
def request_match():
    """マッチングリクエスト受付エンドポイント"""
    try:
        # 認証チェック
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Unauthorized'}), 401
        
        # リクエストデータ取得
        data = request.get_json()
        request_id = data.get('requestId')
        user_id = data.get('userId')
        user_rating = data.get('userRating', 1000)
        force_ai_match = data.get('forceAIMatch', False)
        preferences = data.get('preferences', {})
        
        # Cloud Tasksにマッチング処理を投入
        task = {
            'http_request': {
                'http_method': tasks_v2.HttpMethod.POST,
                'url': f'https://{request.host}/api/match/process',
                'headers': {
                    'Content-Type': 'application/json',
                },
                'body': json.dumps({
                    'requestId': request_id,
                    'userId': user_id,
                    'userRating': user_rating,
                    'forceAIMatch': force_ai_match,
                    'preferences': preferences,
                }).encode(),
            }
        }
        
        # タスクをキューに追加
        parent = tasks_client.queue_path(PROJECT_ID, LOCATION, QUEUE_NAME)
        response = tasks_client.create_task(request={"parent": parent, "task": task})
        
        # 現在のキュー状態を取得して推定待ち時間を計算
        queue_stats = _get_queue_statistics()
        
        # Firestoreのリクエストステータスを更新
        db.collection('matchRequests').document(request_id).update({
            'status': 'searching',
            'queuePosition': queue_stats['position'],
            'estimatedWaitTime': queue_stats['estimated_wait'],
            'searchStartedAt': firestore.SERVER_TIMESTAMP,
        })
        
        return jsonify({
            'success': True,
            'requestId': request_id,
            'queuePosition': queue_stats['position'],
            'estimatedWaitTime': queue_stats['estimated_wait'],
        })
        
    except Exception as e:
        print(f'Error in request_match: {e}')
        return jsonify({'error': str(e)}), 500


@app.route('/api/match/process', methods=['POST'])
def process_match():
    """実際のマッチング処理（Cloud Tasksから呼び出される）"""
    try:
        data = request.get_json()
        request_id = data['requestId']
        user_id = data['userId']
        user_rating = data['userRating']
        force_ai_match = data['forceAIMatch']
        preferences = data.get('preferences', {})
        
        # AI強制マッチングチェック
        if force_ai_match or _should_recommend_ai(user_id, user_rating):
            _create_ai_match(request_id, user_id)
            return jsonify({'success': True, 'type': 'ai_match'})
        
        # 最適なパートナーを探す
        partner = _find_optimal_partner(user_id, user_rating, preferences)
        
        if partner:
            _create_match(request_id, user_id, partner['userId'], partner['requestId'])
            return jsonify({'success': True, 'type': 'user_match'})
        else:
            # パートナーが見つからない場合は再キューイング
            _requeue_with_expanded_criteria(request_id, user_id, user_rating, preferences)
            return jsonify({'success': True, 'type': 'requeued'})
            
    except Exception as e:
        print(f'Error in process_match: {e}')
        # エラー時はリクエストのステータスを更新
        db.collection('matchRequests').document(request_id).update({
            'status': 'error',
            'error': str(e),
            'errorAt': firestore.SERVER_TIMESTAMP,
        })
        return jsonify({'error': str(e)}), 500


def _find_optimal_partner(user_id, user_rating, preferences):
    """最適なパートナーを検索"""
    
    # 初期検索範囲
    rating_range = preferences.get('ratingRange', 200)
    max_range = 500
    
    while rating_range <= max_range:
        # レーティング範囲内の待機中ユーザーを検索
        waiting_users = db.collection('matchRequests') \
            .where('status', '==', 'searching') \
            .where('userId', '!=', user_id) \
            .where('userRating', '>=', user_rating - rating_range) \
            .where('userRating', '<=', user_rating + rating_range) \
            .limit(10) \
            .get()
        
        candidates = []
        for doc in waiting_users:
            partner_data = doc.to_dict()
            
            # AI強制マッチングのユーザーは除外
            if partner_data.get('forceAIMatch', False):
                continue
                
            # 相性スコアを計算
            compatibility = _calculate_compatibility(
                user_rating, 
                partner_data['userRating'],
                preferences,
                partner_data.get('preferences', {})
            )
            
            candidates.append({
                'userId': partner_data['userId'],
                'requestId': doc.id,
                'rating': partner_data['userRating'],
                'compatibility': compatibility,
                'waitTime': _calculate_wait_time(partner_data['createdAt']),
            })
        
        if candidates:
            # 相性スコアと待機時間を考慮してソート
            candidates.sort(key=lambda x: (
                -x['compatibility'],  # 相性スコア（降順）
                x['waitTime']        # 待機時間（昇順）
            ))
            return candidates[0]
        
        # 検索範囲を拡大
        rating_range += 100
    
    return None


def _calculate_compatibility(rating1, rating2, prefs1, prefs2):
    """相性スコアを計算（0-100）"""
    
    # レーティング差によるスコア
    rating_diff = abs(rating1 - rating2)
    rating_score = max(0, 100 - (rating_diff / 10))
    
    # 共通の好みによるボーナス
    common_interests = set(prefs1.get('interests', [])) & set(prefs2.get('interests', []))
    interest_bonus = len(common_interests) * 10
    
    # 地域の近さによるボーナス
    region_bonus = 20 if prefs1.get('region') == prefs2.get('region') else 0
    
    return min(100, rating_score + interest_bonus + region_bonus)


def _create_match(request_id1, user_id1, user_id2, request_id2):
    """マッチングペアを作成"""
    channel_name = f'talkone_{datetime.now().timestamp()}_{np.random.randint(9999)}'
    
    batch = db.batch()
    
    # 両方のリクエストを更新
    batch.update(db.collection('matchRequests').document(request_id1), {
        'status': 'matched',
        'matchedWith': user_id2,
        'channelName': channel_name,
        'matchedAt': firestore.SERVER_TIMESTAMP,
    })
    
    batch.update(db.collection('matchRequests').document(request_id2), {
        'status': 'matched',
        'matchedWith': user_id1,
        'channelName': channel_name,
        'matchedAt': firestore.SERVER_TIMESTAMP,
    })
    
    # マッチング履歴を記録
    match_ref = db.collection('matches').document()
    batch.set(match_ref, {
        'participants': [user_id1, user_id2],
        'requestIds': [request_id1, request_id2],
        'channelName': channel_name,
        'createdAt': firestore.SERVER_TIMESTAMP,
    })
    
    batch.commit()


def _create_ai_match(request_id, user_id):
    """AI練習マッチを作成"""
    channel_name = f'ai_practice_{datetime.now().timestamp()}_{np.random.randint(9999)}'
    ai_partner_id = f'ai_practice_{datetime.now().timestamp()}'
    
    db.collection('matchRequests').document(request_id).update({
        'status': 'matched',
        'matchedWith': ai_partner_id,
        'channelName': channel_name,
        'isDummyMatch': True,
        'isAIMatch': True,
        'matchedAt': firestore.SERVER_TIMESTAMP,
    })


def _requeue_with_expanded_criteria(request_id, user_id, user_rating, preferences):
    """拡大条件で再キューイング"""
    
    # 待機回数を増やす
    doc = db.collection('matchRequests').document(request_id).get()
    retry_count = doc.to_dict().get('retryCount', 0) + 1
    
    if retry_count >= 3:  # 3回リトライ後はAIマッチング
        _create_ai_match(request_id, user_id)
        return
    
    # 検索条件を拡大して再キュー
    expanded_preferences = preferences.copy()
    expanded_preferences['ratingRange'] = preferences.get('ratingRange', 200) + (100 * retry_count)
    
    # 10秒後に再処理するタスクを作成
    task = {
        'http_request': {
            'http_method': tasks_v2.HttpMethod.POST,
            'url': f'https://{request.host}/api/match/process',
            'headers': {
                'Content-Type': 'application/json',
            },
            'body': json.dumps({
                'requestId': request_id,
                'userId': user_id,
                'userRating': user_rating,
                'forceAIMatch': False,
                'preferences': expanded_preferences,
            }).encode(),
        },
        'schedule_time': datetime.now() + timedelta(seconds=10),
    }
    
    parent = tasks_client.queue_path(PROJECT_ID, LOCATION, QUEUE_NAME)
    tasks_client.create_task(request={"parent": parent, "task": task})
    
    # ステータス更新
    db.collection('matchRequests').document(request_id).update({
        'retryCount': retry_count,
        'nextRetryAt': firestore.SERVER_TIMESTAMP,
    })


def _should_recommend_ai(user_id, user_rating):
    """AI練習を推奨すべきか判定"""
    if user_rating <= 800:
        return True
    
    # 最近の評価履歴をチェック
    recent_evals = db.collection('evaluations') \
        .where('evaluatedUserId', '==', user_id) \
        .order_by('createdAt', direction=firestore.Query.DESCENDING) \
        .limit(5) \
        .get()
    
    if len(recent_evals) >= 3:
        ratings = [eval.to_dict()['rating'] for eval in recent_evals]
        avg_rating = sum(ratings) / len(ratings)
        return avg_rating <= 2.5
    
    return False


def _get_queue_statistics():
    """キューの統計情報を取得"""
    # 待機中のリクエスト数をカウント
    waiting_count = db.collection('matchRequests') \
        .where('status', '==', 'searching') \
        .count() \
        .get()[0][0].value
    
    # 平均マッチング時間を計算（過去1時間のデータから）
    one_hour_ago = datetime.now() - timedelta(hours=1)
    recent_matches = db.collection('matches') \
        .where('createdAt', '>=', one_hour_ago) \
        .limit(50) \
        .get()
    
    if recent_matches:
        # 簡易的な推定
        avg_wait_seconds = 30  # デフォルト30秒
    else:
        avg_wait_seconds = 45
    
    return {
        'position': waiting_count + 1,
        'estimated_wait': int(avg_wait_seconds * (waiting_count + 1) / 2),
    }


def _calculate_wait_time(created_at):
    """待機時間を計算（秒）"""
    if not created_at:
        return 0
    return (datetime.now() - created_at).total_seconds()


@app.route('/api/match/cancel', methods=['POST'])
def cancel_match():
    """マッチングキャンセル"""
    try:
        data = request.get_json()
        request_id = data['requestId']
        user_id = data['userId']
        
        # リクエストの所有者確認
        doc = db.collection('matchRequests').document(request_id).get()
        if not doc.exists or doc.to_dict()['userId'] != user_id:
            return jsonify({'error': 'Unauthorized'}), 403
        
        # ステータス更新
        db.collection('matchRequests').document(request_id).update({
            'status': 'cancelled',
            'cancelledAt': firestore.SERVER_TIMESTAMP,
        })
        
        return jsonify({'success': True})
        
    except Exception as e:
        print(f'Error in cancel_match: {e}')
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))