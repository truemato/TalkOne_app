# VOICEVOX Engine for Cloud Run
FROM voicevox/voicevox_engine:cpu-latest

# Cloud Run用のスタートアップスクリプトを作成（non-blocking TTS設定）
RUN echo '#!/bin/bash\ngosu user /opt/python/bin/python3 ./run.py --voicelib_dir /opt/voicevox_core/ --runtime_dir /opt/onnxruntime/lib --host 0.0.0.0 --port ${PORT:-50021} --allow_origin "*" --enable_cancellable_synthesis --init_processes 5' > /start.sh && chmod +x /start.sh

# Cloud RunのPORT環境変数を使用
EXPOSE $PORT

# スタートアップスクリプトを実行
CMD ["/start.sh"]