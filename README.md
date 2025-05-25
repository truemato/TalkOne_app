<!-- PROJECT HEADER -->
<h1 align="center">TalkOne</h1>
<p align="center">
  <b>1 ⇄ 1 ランダムマッチング型ビデオ通話アプリ</b><br/>
  <i>プライバシー特化・AI フィルタ内蔵・評価ベース自動マッチング</i>
</p>

<p align="center">
  <!-- License badge -->
  <a href="license/mit.md">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"/>
  </a>

## 📚 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Getting Started](#getting-started)
- [License](#license)

---

## 📝 Overview

TalkOne is a **1‑on‑1 video chat platform** that pairs strangers in real‑time while keeping their identity private.  
It overlays an *Animoji‑style* 3‑D face on top of the camera feed and mutes the microphone by default, letting users speak only while holding the push‑to‑talk button.  
After each call both parties rate the experience, and accounts with chronically low ratings are automatically matched with an AI agent powered by Gemini.

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

---

## 🤝 Contributing

1. Issue を立ててバグ報告 / 機能提案  
2. `git checkout -b feat/my-awesome-feature` でブランチを切る  
3. `flutter analyze` と `flutter test` が green になることを確認  
4. Pull Request を送る → GitHub Actions が通ればマージ 🎉

---

## 🪪 License

Distributed under the **MIT License**.  
See [`LICENSE`](LICENSE) for more information.
