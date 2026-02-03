package com.example.visiaxx

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.View
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.visiaxx/voice"
    private var speechRecognizer: SpeechRecognizer? = null
    private var recognitionIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    startListening(result)
                }
                "stopListening" -> {
                    stopListening(result)
                }
                "cancelListening" -> {
                    cancelListening(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startListening(result: MethodChannel.Result) {
        // Run on UI thread as required by SpeechRecognizer
        runOnUiThread {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
                return@runOnUiThread
            }

            try {
                // CLEAN START: Forcefully destroy any existing recognizer
                // to prevent carry-over and address "stuck" states.
                speechRecognizer?.let {
                    it.stopListening()
                    it.cancel()
                    it.destroy()
                }
                speechRecognizer = null

                // Fresh instance for every session
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                recognitionIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }
                }

                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        runOnUiThread {
                            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@runOnUiThread, CHANNEL)
                                .invokeMethod("onStatus", "listening")
                        }
                    }

                    override fun onBeginningOfSpeech() {}
                    
                    override fun onRmsChanged(rmsdB: Float) {
                        runOnUiThread {
                            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@runOnUiThread, CHANNEL)
                                .invokeMethod("onRmsChanged", rmsdB)
                        }
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {}
                    
                    override fun onEndOfSpeech() {
                        runOnUiThread {
                            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@runOnUiThread, CHANNEL)
                                .invokeMethod("onStatus", "processing")
                        }
                    }

                    override fun onError(error: Int) {
                        runOnUiThread {
                            val errorMessage = getErrorText(error)
                            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@runOnUiThread, CHANNEL)
                                .invokeMethod("onError", errorMessage)
                            
                            // If it fails immediately, notify Flutter
                            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@runOnUiThread, CHANNEL)
                                .invokeMethod("onStatus", "failed")
                        }
                    }

                    override fun onResults(results: Bundle?) {
                        runOnUiThread {
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@runOnUiThread, CHANNEL)
                                    .invokeMethod("onResults", mapOf(
                                        "text" to matches[0],
                                        "isFinal" to true
                                    ))
                            }
                        }
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        runOnUiThread {
                            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@runOnUiThread, CHANNEL)
                                    .invokeMethod("onResults", mapOf(
                                        "text" to matches[0],
                                        "isFinal" to false
                                    ))
                            }
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                speechRecognizer?.startListening(recognitionIntent)
                result.success(true)
            } catch (e: Exception) {
                result.error("INIT_FAILED", e.message, null)
            }
        }
    }

    private fun stopListening(result: MethodChannel.Result) {
        runOnUiThread {
            speechRecognizer?.stopListening()
            result.success(true)
        }
    }

    private fun cancelListening(result: MethodChannel.Result) {
        runOnUiThread {
            speechRecognizer?.cancel()
            result.success(true)
        }
    }

    private fun getErrorText(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RecognitionService busy"
            SpeechRecognizer.ERROR_SERVER -> "Error from server"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
            else -> "Unknown error: $errorCode"
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupWindowInsets()
    }

    private fun setupWindowInsets() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = 
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        windowInsetsController?.apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        window.decorView.setOnApplyWindowInsetsListener { view, insets ->
            view.setPadding(0, 0, 0, 0)
            insets
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN)
    }

    override fun onPostResume() {
        super.onPostResume()
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        super.onDestroy()
    }
}