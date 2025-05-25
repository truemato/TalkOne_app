<!-- PROJECT HEADER -->
<h1 align="center">TalkOne</h1>
<p align="center">
  <b>1 ⇄ 1 ランダムマッチング型ビデオ通話アプリ</b><br/>
  <i>プライバシー特化・AI フィルタ内蔵・評価ベース自動マッチング</i>
</p>

<p align="center">
  <!-- License badge -->
  <a href="mit.md">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"/>
  </a>

## 📚 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Getting Started](#getting-started)

---

## 📝 Overview


TalkOne は <ruby>1対1<rt>いち たい いち</rt></ruby> の <ruby>ビデオチャット<rt>びでお ちゃっと</rt></ruby> アプリです。  
<ruby>見た目<rt>みため</rt></ruby> と <ruby>名前<rt>なまえ</rt></ruby> を <ruby>隠<rt>かく</rt></ruby>して、 <ruby>知らない<rt>しらない</rt></ruby> 人と すぐに 話す ことができます。  
カメラの 上に アニメの 顔を つけて、 <ruby>普段<rt>ふだん</rt></ruby> は マイクを オフにします。 話したい とき だけ ボタンを 押しながら 声を 出します。  
<ruby>会話<rt>かいわ</rt></ruby> が 終わったら、 二人とも その 会話を 3 段階で <ruby>評価<rt>ひょうか</rt></ruby> します。 <ruby>評価<rt>ひょうか</rt></ruby> が 低い 人は 次から AI（Gemini）と マッチング されます。  

---

## ✨ Features
| 区分 | 概要 |
|------|------|
| 🔀 **ランダムマッチング** | ボタン 1 つでランダムな相手と接続 |
| 🫥 **AI 顔置換** | Mediapipe Pose + TFLite でリアルタイムに Animoji 風フェイスへ変換 |
| 🔊 **Push-to-Talk** | デフォルトでミュート、長押しで発話できる安全設計 |
| 🏅 **ポストコール評価** | 会話終了ごとに 👍 / 😐 / 👎 3 段階評価 |
| 🤖 **AI マッチング** | 低評価が蓄積すると次回以降は Gemini API ベースの AI が相手に |
| 🗂 **チャットログ** | Firestore に匿名化データを保存し、後で学習／改善に活用 |
| 🌐 **Multiplatform** | iOS / Android / Web（β）を Flutter 1 codebase で提供 |

---

## 🚀 Getting Started

### Prerequisites

- Flutter 3.22 or later  
- Dart ≥ 3.4.0  
- Firebase CLI (`npm i -g firebase-tools`)  
- (Optional) `melos` for workspace tasks  

### 1. Clone

```bash
git clone https://github.com/truemato/TalkOne.git
cd TalkOne
```

### 2. Configure secrets

```bash
cp .env.example .env          # edit with your own keys
```

### 3. Install dependencies

```bash
flutter pub get
cd functions && npm ci        # Cloud Functions deps
```

### 4. Run locally

```bash
firebase emulators:start &    # Firestore/Auth emu
flutter run -d chrome         # or -d ios / -d android
```