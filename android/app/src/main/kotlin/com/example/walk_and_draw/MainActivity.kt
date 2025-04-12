package com.programmersdiary.walk_and_draw

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.programmersdiary.walk_and_draw/config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getGeminiApiKey" -> {
                    val apiKey = context.getString(R.string.gemini_api_key)
                    result.success(apiKey)
                }
                "getMongoDBUsername" -> {
                    val username = context.getString(R.string.mongodb_atlas_username)
                    result.success(username)
                }
                "getMongoDBPassword" -> {
                    val password = context.getString(R.string.mongodb_atlas_password)
                    result.success(password)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}