# Dockerfile for Agora Token Service
FROM python:3.9-slim

# 作業ディレクトリを設定
WORKDIR /app

# 依存関係をコピーしてインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY main.py .

# Firebaseサービスアカウントキー用の環境変数を設定
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/service-account-key.json"

# ポート8080で起動
EXPOSE 8080

# Gunicornでアプリケーションを起動
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "main:app"]