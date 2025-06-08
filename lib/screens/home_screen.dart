// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'matching_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2E0F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TalkOneロゴ
              const Text(
                'TalkOne',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E1E),
                  letterSpacing: -4.48,
                  fontFamily: 'Catamaran',
                ),
              ),
              
              const SizedBox(height: 60),
              
              // 説明テキスト
              const Text(
                'レーティングベースマッチングで\n同じレベルの相手と会話しよう',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1E1E1E),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 80),
              
              // 音声通話ボタン
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MatchingScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone, size: 28),
                  label: const Text(
                    '音声通話を開始',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2CEF7),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // AI練習ボタン
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MatchingScreen(forceAIMatch: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy, size: 28),
                  label: const Text(
                    'AI練習モード',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[200],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // フッター情報
              const Text(
                'レーティングシステムで成長を実感\n会話スキルを向上させよう',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}