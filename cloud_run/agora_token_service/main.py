import os
import time
import json
from flask import Flask, request, jsonify
from flask_cors import CORS
from agora_token_builder import RtcTokenBuilder
from firebase_admin import credentials, firestore, initialize_app
from datetime import datetime, timedelta

app = Flask(__name__)

# CORSを設定（Flutter Webからのアクセスを許可）
CORS(app, origins=["http://localhost:*", "https://*.web.app", "https://*.firebaseapp.com"])

# Firebase初期化
cred = credentials.ApplicationDefault()
initialize_app(cred)
db = firestore.client()

# Agora設定（環境変数から取得）
AGORA_APP_ID = os.environ.get('AGORA_APP_ID')
AGORA_APP_CERTIFICATE = os.environ.get('AGORA_APP_CERTIFICATE')

# トークンの有効期限（秒）
TOKEN_EXPIRATION_TIME = 3600  # 1時間

@app.route('/agora/token', methods=['POST'])
def generate_token():
    """Agoraトークンを生成"""
    try:
        data = request.json
        channel_name = data.get('channel_name')
        uid = data.get('uid', 0)
        user_id = data.get('user_id')
        
        if not channel_name:
            return jsonify({
                'success': False,
                'error': 'channel_name is required'
            }), 400
        
        # ユーザー認証確認
        if not user_id:
            return jsonify({
                'success': False,
                'error': 'user_id is required'
            }), 401
        
        # トークン生成
        current_timestamp = int(time.time())
        privilege_expired_ts = current_timestamp + TOKEN_EXPIRATION_TIME
        
        token = RtcTokenBuilder.buildTokenWithUid(
            AGORA_APP_ID,
            AGORA_APP_CERTIFICATE,
            channel_name,
            uid,
            RtcTokenBuilder.Role_Publisher,
            privilege_expired_ts
        )
        
        # 通話記録をFirestoreに保存（課金用）
        call_record = {
            'user_id': user_id,
            'channel_name': channel_name,
            'uid': uid,
            'token_generated_at': firestore.SERVER_TIMESTAMP,
            'token_expires_at': datetime.utcnow() + timedelta(seconds=TOKEN_EXPIRATION_TIME),
            'call_type': data.get('call_type', 'voice'),  # voice or video
        }
        
        db.collection('call_records').add(call_record)
        
        return jsonify({
            'success': True,
            'token': token,
            'expires_in': TOKEN_EXPIRATION_TIME
        })
        
    except Exception as e:
        print(f'トークン生成エラー: {e}')
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/agora/refresh', methods=['POST'])
def refresh_token():
    """トークンを更新"""
    try:
        data = request.json
        channel_name = data.get('channel_name')
        uid = data.get('uid', 0)
        user_id = data.get('user_id')
        old_token = data.get('old_token')
        
        # 既存のトークンの検証
        # 実装省略（本番環境では必要）
        
        # 新しいトークン生成
        current_timestamp = int(time.time())
        privilege_expired_ts = current_timestamp + TOKEN_EXPIRATION_TIME
        
        new_token = RtcTokenBuilder.buildTokenWithUid(
            AGORA_APP_ID,
            AGORA_APP_CERTIFICATE,
            channel_name,
            uid,
            RtcTokenBuilder.Role_Publisher,
            privilege_expired_ts
        )
        
        # トークン更新記録
        db.collection('token_refreshes').add({
            'user_id': user_id,
            'channel_name': channel_name,
            'refreshed_at': firestore.SERVER_TIMESTAMP,
        })
        
        return jsonify({
            'success': True,
            'token': new_token,
            'expires_in': TOKEN_EXPIRATION_TIME
        })
        
    except Exception as e:
        print(f'トークン更新エラー: {e}')
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/agora/end_call', methods=['POST'])
def end_call():
    """通話終了を記録（課金計算用）"""
    try:
        data = request.json
        channel_name = data.get('channel_name')
        user_id = data.get('user_id')
        duration = data.get('duration', 0)  # 秒
        
        # 通話終了記録
        end_record = {
            'user_id': user_id,
            'channel_name': channel_name,
            'ended_at': firestore.SERVER_TIMESTAMP,
            'duration_seconds': duration,
            'duration_minutes': duration / 60,
            'estimated_cost': calculate_cost(duration, data.get('call_type', 'voice')),
        }
        
        db.collection('call_end_records').add(end_record)
        
        # ユーザーの通話統計を更新
        update_user_stats(user_id, duration)
        
        return jsonify({
            'success': True,
            'duration': duration,
            'estimated_cost': end_record['estimated_cost']
        })
        
    except Exception as e:
        print(f'通話終了記録エラー: {e}')
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def calculate_cost(duration_seconds, call_type):
    """通話コストを計算（Agoraの料金体系に基づく）"""
    duration_minutes = duration_seconds / 60
    
    # Agoraの料金例（実際の料金は公式サイトを確認）
    # 音声: $0.99/1000分
    # ビデオ(SD): $3.99/1000分
    # ビデオ(HD): $8.99/1000分
    
    if call_type == 'voice':
        rate_per_minute = 0.99 / 1000
    elif call_type == 'video':
        rate_per_minute = 3.99 / 1000  # SD品質と仮定
    else:
        rate_per_minute = 0.99 / 1000
    
    return round(duration_minutes * rate_per_minute, 4)

def update_user_stats(user_id, duration_seconds):
    """ユーザーの通話統計を更新"""
    user_ref = db.collection('users').document(user_id)
    
    # トランザクションで更新
    @firestore.transactional
    def update_in_transaction(transaction):
        user_doc = user_ref.get(transaction=transaction)
        
        if user_doc.exists:
            data = user_doc.to_dict()
            current_total = data.get('total_call_duration', 0)
            current_count = data.get('total_call_count', 0)
            
            transaction.update(user_ref, {
                'total_call_duration': current_total + duration_seconds,
                'total_call_count': current_count + 1,
                'last_call_at': firestore.SERVER_TIMESTAMP,
            })
        else:
            transaction.set(user_ref, {
                'total_call_duration': duration_seconds,
                'total_call_count': 1,
                'last_call_at': firestore.SERVER_TIMESTAMP,
            })
    
    transaction = db.transaction()
    update_in_transaction(transaction)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))