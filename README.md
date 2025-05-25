license: MIT

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
    <img src="https://img.shields.io/github/license/truemato/TalkOne" alt="License"/>
  </a>
  <!-- Stars badge (optional / shields.io) -->
  <img src="https://img.shields.io/github/stars/truemato/TalkOne?style=social" alt="Stars"/>
</p>

![demo](docs/assets/demo_call.gif)

---

## 📚 Table of Contents

1. [Features](#features)  
2. [Tech Stack](#tech-stack)  
3. [Architecture](#architecture)  
4. [Getting Started](#getting-started)  
5. [Configuration](#configuration)  
6. [Folder Structure](#folder-structure)  
7. [Scripts](#scripts)  
8. [Contributing](#contributing)  
9. [License](#license)

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