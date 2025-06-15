import os
import json
import base64
from flask import Flask, request, jsonify
from google.cloud import speech_v1
from google.cloud import texttospeech
import google.generativeai as genai
from firebase_admin import credentials, firestore, initialize_app

app = Flask(__name__)

# Firebase初期化
cred = credentials.ApplicationDefault()
initialize_app(cred)
db = firestore.client()

# Gemini設定
genai.configure(api_key=os.environ.get('GEMINI_API_KEY'))

# 音声認識クライアント
speech_client = speech_v1.SpeechClient()

# 音声合成クライアント
tts_client = texttospeech.TextToSpeechClient()

@app.route('/voice/transcribe', methods=['POST'])
def transcribe_audio():
    """音声をテキストに変換"""
    try:
        data = request.json
        audio_data = base64.b64decode(data['audio'])
        
        # Google Speech-to-Text設定
        audio = speech_v1.RecognitionAudio(content=audio_data)
        config = speech_v1.RecognitionConfig(
            encoding=speech_v1.RecognitionConfig.AudioEncoding.WEBM_OPUS,
            sample_rate_hertz=48000,
            language_code="ja-JP",
            enable_automatic_punctuation=True,
        )
        
        # 音声認識実行
        response = speech_client.recognize(config=config, audio=audio)
        
        transcript = ""
        for result in response.results:
            transcript += result.alternatives[0].transcript
        
        return jsonify({
            'success': True,
            'transcript': transcript
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/voice/generate', methods=['POST'])
def generate_response():
    """Gemini 2.5でテキスト生成し、音声に変換"""
    try:
        data = request.json
        user_text = data['text']
        personality_id = data.get('personality_id', 0)
        user_id = data.get('user_id')
        
        # Gemini 2.5モデル
        model = genai.GenerativeModel('gemini-2.5-flash-preview-05-20')
        
        # 人格システムプロンプト取得
        system_prompt = get_personality_prompt(personality_id, user_id)
        
        # Geminiで応答生成
        chat = model.start_chat()
        response = chat.send_message(f"{system_prompt}\n\nユーザー: {user_text}")
        ai_text = response.text
        
        # Google Text-to-Speech設定
        synthesis_input = texttospeech.SynthesisInput(text=ai_text)
        
        # 音声設定（日本語女性音声）
        voice = texttospeech.VoiceSelectionParams(
            language_code="ja-JP",
            name="ja-JP-Neural2-B",  # より自然な音声
            ssml_gender=texttospeech.SsmlVoiceGender.FEMALE
        )
        
        # 音声合成設定
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=1.0,
            pitch=0.0,
        )
        
        # 音声合成実行
        tts_response = tts_client.synthesize_speech(
            input=synthesis_input,
            voice=voice,
            audio_config=audio_config
        )
        
        # Base64エンコード
        audio_base64 = base64.b64encode(tts_response.audio_content).decode('utf-8')
        
        return jsonify({
            'success': True,
            'text': ai_text,
            'audio': audio_base64,
            'audio_format': 'mp3'
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/voice/stream', methods=['POST'])
def stream_response():
    """リアルタイムストリーミング用エンドポイント"""
    # WebSocketまたはServer-Sent Eventsで実装
    pass

def get_personality_prompt(personality_id, user_id):
    """人格システムプロンプトを取得"""
    personalities = {
        0: "あなたは「さくら」という名前の優しいお姉さんです。",
        1: "あなたは「りん」という名前の元気な妹キャラです。",
        2: "あなたは「みお」という名前のクールな先輩です。",
        3: "あなたは「ゆい」という名前の天然な友達です。",
        4: "あなたは「あかり」という名前の真面目な委員長タイプです。",
    }
    return personalities.get(personality_id, personalities[0])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))