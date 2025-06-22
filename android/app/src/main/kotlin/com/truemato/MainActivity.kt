package com.truemato

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.truemato.talkone.AndroidSpeechRecognizer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.talkone.app/ai_filter"
    private val SPEECH_CHANNEL = "android_speech_recognizer"
    
    private lateinit var androidSpeechRecognizer: AndroidSpeechRecognizer
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Android音声認識チャンネルの設定
        val speechMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        androidSpeechRecognizer = AndroidSpeechRecognizer(this, speechMethodChannel)
        
        // Set up method channel (temporary implementation without AI filter)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeAIFilter" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                "enableAIFilter" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                "setFilterParams" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                "releaseAIFilter" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
