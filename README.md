<!-- PROJECT HEADER -->
<h1 align="center">TalkOne</h1>
<p align="center">
  <b>1 ⇄ 1 ランダムマッチング型ビデオ通話アプリ</b><br/>
  <i>プライバシー特化・AI フィルタ内蔵・評価ベース自動マッチング</i>
</p>

<p align="center">
  <!-- GitHub Actions badge -->
  <a href="https://github.com/truemato/TalkOne/actions">
    <img src="https://github.com/truemato/TalkOne/actions/workflows/flutter.yml/badge.svg" alt="CI Status"/>
  </a>
  <!-- License badge -->
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"/>
  </a>
  <!-- Stars badge (optional / shields.io) -->
  <img src="https://img.shields.io/github/stars/truemato/TalkOne?style=social" alt="Stars"/>
</p>

![demo](docs/assets/demo_call.gif)

---

## 📚 Table of Contents

- [Overview](#overview)
- [Background & Purpose](#background--purpose)
- [Features](#features)
- [Improvements](#improvements)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Folder Structure](#folder-structure)
- [Development Rules](#development-rules)
- [Scripts](#scripts)
- [Usage](#usage)
- [Tests](#tests)
- [Contributing](#contributing)
- [License](#license)

---

## 📝 Overview

TalkOne is a **1‑on‑1 video chat platform** that pairs strangers in real‑time while keeping their identity private.  
It overlays an *Animoji‑style* 3‑D face on top of the camera feed and mutes the microphone by default, letting users speak only while holding the push‑to‑talk button.  
After each call both parties rate the experience, and accounts with chronically low ratings are automatically matched with an AI agent powered by Gemini.

## 🎯 Background & Purpose

- Created during a weekend hackathon to explore **privacy‑first social interactions**.  
- Demonstrates a full **Flutter × Firebase × Vertex AI** stack running in production.  
- Serves as a sandbox for experimenting with *real‑time vision overlays* and *serverless matchmaking logic*.

## 💡 Improvements

- **Layered Clean Architecture** — clear separation between Presentation / Application / Domain / Infrastructure.  
- **Typed Firestore** via `flutterfire` generator eliminates string literals in queries.  
- **Secure by Design** — secrets stored in Cloud Secret Manager; client receives only time‑limited tokens.  
- **Progressive Enhancement** — core chat runs on low‑end Android (SDK 24); AI filter toggles off gracefully on devices without sufficient GPU.  
- **Fast CI** — GitHub Actions completes in < 5 minutes by caching Flutter and Node modules.

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

## 🏗️ Tech Stack

| Layer | Technology | 用途 |
|-------|------------|------|
| Frontend | **Flutter 3.22** | UI / StateMgmt (Riverpod) |
| Realtime Media | **ZEGOCLOUD SDK** | WebRTC ベースの低遅延ビデオ通話 |
| AI Filter | **Google ML Kit** / **Mediapipe** | 顔ランドマーク検出 & 3D モデリング |
| Backend | **Firebase (v9)** | Auth ・ Cloud Firestore ・ Cloud Functions ・ Storage |
| AI Chat | **Gemini 2.x (Vertex AI)** | AI 相手モード／不適切発言フィルタリング |
| IaC | **Terraform** | Firebase プロジェクト・Cloud Functions デプロイ |
| CI | **GitHub Actions** | PR ごとに `flutter test` / `flutter analyze` / apk/ipa build |

---

## 🗺 Architecture

```mermaid
graph TD
  subgraph Client (Flutter)
    UI -->|push-to-talk| Recorder
    UI --> Matcher
    Camera --> FaceFilter --> RTC
    RTC -->|WebRTC| ZegoSDK
  end

  subgraph Firebase
    Auth <--> Functions
    Firestore <--> Functions
    Storage <--> Functions
  end

  subgraph Cloud Functions
    MatcherFN --> Firestore
    RatingFN --> Firestore
    RatingFN --> VertexAI["Gemini 2.x"]
  end

  ZegoSDK <-->|Signal| SignalingSrv
```

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

## ⚙️ Configuration

| Key | Example | Description |
|-----|---------|-------------|
| `GEMINI_API_KEY`     | `AIza…`         | Vertex AI Gemini |
| `ZEGOCLOUD_APP_ID`   | `123456789`     | Console‑issued   |
| `ZEGOCLOUD_APP_SIGN` | `abcdef0123…`   | Console‑issued   |
| `FIREBASE_PROJECT_ID`| `talkone-dev`   | Firebase project |
| `SENTRY_DSN`         | `https://…`     | *optional*       |

---

## 🗂 Folder Structure

```text
TalkOne/
├── lib/
│   ├── presentation/   # UI widgets & screens
│   ├── application/    # State (Riverpod providers)
│   ├── domain/         # Entities & repositories
│   └── infra/          # Data sources & API clients
├── functions/          # Firebase Cloud Functions
├── docs/               # Architecture docs & assets
└── test/               # Unit & widget tests
```

---

## 📜 Scripts

| Command                                              | Purpose                       |
|------------------------------------------------------|-------------------------------|
| `flutter pub run build_runner watch --delete-conflicting-outputs` | Code generation            |
| `melos run analyze`                                  | Lint & format check           |
| `melos run coverage`                                 | Run tests & output coverage   |
| `firebase deploy --only functions`                   | Deploy Cloud Functions        |
| `./scripts/bump_version.sh 1.2.0`                    | Bump app version everywhere   |

---

## 🛠 Development Rules

- Follow **Conventional Commits** (`feat:`, `fix:`, `docs:` …).  
- Always open a **Draft PR** early; CI and reviewers kick in automatically.  
- Run `melos run analyze` locally; no lint‑errors ⇒ no merge.  
- Each PR must include either **unit tests** or **golden‑image tests** for UI changes.

## 🚚 Usage

```bash
# Production build (Android)
flutter build apk --release

# iOS TestFlight build
flutter build ipa --export-options-plist=ios/ExportOptions.plist
```

Deploy backend (Firestore rules & Cloud Functions):

```bash
firebase deploy --only firestore,functions
```

## 🧪 Tests

```bash
# Dart unit & widget tests + coverage
melos run coverage

# Cloud Functions tests
cd functions && npm test
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

---

<p align="center">
Made with ❤️ & ☕ by <a href="https://github.com/truemato">truemato</a>
</p>