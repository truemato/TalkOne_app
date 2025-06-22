#!/usr/bin/env python3
"""
VOICEVOX Engine Text-to-Speech API Wrapper
non-blocking TTS対応の一発音声変換API

Usage:
    POST /tts
    {
        "text": "こんにちは",
        "speaker": 3,
        "speed": 1.0,
        "pitch": 0.0,
        "intonation": 1.0,
        "volume": 1.0
    }

Response:
    audio/wav binary data
"""

import os
import json
import logging
import asyncio
import aiohttp
from flask import Flask, request, Response, jsonify
from typing import Optional
import urllib.parse

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# VOICEVOX Engine設定
VOICEVOX_HOST = "http://localhost:50021"
DEFAULT_SPEAKER = 3  # ずんだもん
ENGINE_WARMUP_COUNT = 2  # マッチング時に起動するエンジン数

class VoicevoxTTSAPI:
    def __init__(self, host: str = VOICEVOX_HOST):
        self.host = host
        self.session: Optional[aiohttp.ClientSession] = None
        self.engines_warmed = False
    
    async def get_session(self) -> aiohttp.ClientSession:
        """HTTPセッションを取得"""
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession()
        return self.session
    
    async def close_session(self):
        """HTTPセッションを閉じる"""
        if self.session and not self.session.closed:
            await self.session.close()
    
    async def warmup_engines(self, count: int = ENGINE_WARMUP_COUNT):
        """エンジンのウォームアップ（コールドスタート対策）"""
        if self.engines_warmed:
            logger.info("エンジンは既にウォームアップ済みです")
            return
        
        try:
            session = await self.get_session()
            warmup_text = "ウォームアップ"
            
            # 複数エンジンの同時ウォームアップ
            tasks = []
            for i in range(count):
                task = self._synthesize_audio(
                    session=session,
                    text=f"{warmup_text}{i+1}",
                    speaker=DEFAULT_SPEAKER
                )
                tasks.append(task)
            
            # 並列実行
            await asyncio.gather(*tasks, return_exceptions=True)
            self.engines_warmed = True
            logger.info(f"{count}個のエンジンをウォームアップしました")
            
        except Exception as e:
            logger.error(f"エンジンウォームアップエラー: {e}")
    
    async def _synthesize_audio(
        self,
        session: aiohttp.ClientSession,
        text: str,
        speaker: int,
        speed: float = 1.0,
        pitch: float = 0.0,
        intonation: float = 1.0,
        volume: float = 1.0
    ) -> bytes:
        """音声合成（internal）"""
        try:
            # 1. audio_query作成
            encoded_text = urllib.parse.quote(text)
            query_url = f"{self.host}/audio_query?text={encoded_text}&speaker={speaker}"
            
            async with session.post(query_url) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"audio_query失敗 ({response.status}): {error_text}")
                
                query_json = await response.json()
            
            # 2. パラメータ適用
            query_json.update({
                'speedScale': speed,
                'pitchScale': pitch,
                'intonationScale': intonation,
                'volumeScale': volume
            })
            
            # 3. non-blocking音声合成
            synthesis_url = f"{self.host}/cancellable_synthesis?speaker={speaker}"
            headers = {'Content-Type': 'application/json'}
            
            async with session.post(
                synthesis_url,
                headers=headers,
                json=query_json,
                timeout=aiohttp.ClientTimeout(total=30)
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"音声合成失敗 ({response.status}): {error_text}")
                
                audio_data = await response.read()
                return audio_data
                
        except asyncio.TimeoutError:
            raise Exception("音声合成タイムアウト（30秒）")
        except Exception as e:
            logger.error(f"音声合成エラー: {e}")
            raise
    
    async def text_to_speech(
        self,
        text: str,
        speaker: int = DEFAULT_SPEAKER,
        speed: float = 1.0,
        pitch: float = 0.0,
        intonation: float = 1.0,
        volume: float = 1.0
    ) -> bytes:
        """テキストから音声への一発変換"""
        if not text.strip():
            raise ValueError("テキストが空です")
        
        # 140文字制限
        if len(text) > 140:
            text = text[:140]
            logger.warning(f"テキストを140文字に制限: {text}")
        
        session = await self.get_session()
        return await self._synthesize_audio(
            session=session,
            text=text,
            speaker=speaker,
            speed=speed,
            pitch=pitch,
            intonation=intonation,
            volume=volume
        )

# グローバルAPIインスタンス
tts_api = VoicevoxTTSAPI()

@app.route('/health', methods=['GET'])
def health_check():
    """ヘルスチェック"""
    return jsonify({
        'status': 'healthy',
        'service': 'voicevox-tts-api',
        'engines_warmed': tts_api.engines_warmed
    })

@app.route('/warmup', methods=['POST'])
async def warmup_engines():
    """エンジンウォームアップ（マッチング時呼び出し）"""
    try:
        await tts_api.warmup_engines(count=ENGINE_WARMUP_COUNT)
        return jsonify({
            'status': 'success',
            'message': f'{ENGINE_WARMUP_COUNT}個のエンジンをウォームアップしました',
            'engines_warmed': True
        })
    except Exception as e:
        logger.error(f"ウォームアップエラー: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/tts', methods=['POST'])
async def text_to_speech():
    """テキスト音声合成API"""
    try:
        # リクエストデータ取得
        data = request.get_json()
        if not data:
            return jsonify({'error': 'JSONデータが必要です'}), 400
        
        text = data.get('text', '').strip()
        if not text:
            return jsonify({'error': 'textパラメータが必要です'}), 400
        
        # パラメータ取得（デフォルト値あり）
        speaker = data.get('speaker', DEFAULT_SPEAKER)
        speed = data.get('speed', 1.0)
        pitch = data.get('pitch', 0.0)
        intonation = data.get('intonation', 1.0)
        volume = data.get('volume', 1.0)
        
        logger.info(f"TTS要求: speaker={speaker}, text=\"{text[:50]}...\"")
        
        # 音声合成実行
        audio_data = await tts_api.text_to_speech(
            text=text,
            speaker=speaker,
            speed=speed,
            pitch=pitch,
            intonation=intonation,
            volume=volume
        )
        
        # WAVデータをレスポンス
        return Response(
            audio_data,
            mimetype='audio/wav',
            headers={
                'Content-Disposition': 'attachment; filename="speech.wav"',
                'Cache-Control': 'no-cache'
            }
        )
        
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        logger.error(f"TTS API エラー: {e}")
        return jsonify({'error': '音声合成に失敗しました'}), 500

@app.route('/speakers', methods=['GET'])
async def get_speakers():
    """利用可能な話者一覧取得"""
    try:
        session = await tts_api.get_session()
        async with session.get(f"{tts_api.host}/speakers") as response:
            if response.status != 200:
                raise Exception(f"話者取得失敗: {response.status}")
            
            speakers_data = await response.json()
            return jsonify(speakers_data)
            
    except Exception as e:
        logger.error(f"話者取得エラー: {e}")
        return jsonify({'error': '話者一覧の取得に失敗しました'}), 500

@app.before_first_request
async def initialize_app():
    """アプリ初期化"""
    logger.info("VOICEVOX TTS API サーバー起動中...")

@app.teardown_appcontext
async def cleanup(error):
    """クリーンアップ"""
    if error:
        logger.error(f"アプリケーションエラー: {error}")

if __name__ == '__main__':
    # 本番環境用（Cloud Run）
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)