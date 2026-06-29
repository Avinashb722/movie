package com.example.flixo_app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val MAGNET_CHANNEL = "com.example.flixo_app/magnet"
    private val TORRENT_CHANNEL = "com.example.flixo_app/torrent"
    private var pendingMagnetLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d("MainActivity", "configureFlutterEngine called — registering MethodChannels")

        // Initialize TorrentEngine with application context
        TorrentEngine.init(applicationContext)
        Log.d("MainActivity", "TorrentEngine.init() done")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAGNET_CHANNEL).setMethodCallHandler { call, result ->
            Log.d("MainActivity", "[MAGNET_CHANNEL] Method called: ${call.method}")
            when (call.method) {
                "getPendingMagnet" -> {
                    result.success(pendingMagnetLink)
                    pendingMagnetLink = null
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TORRENT_CHANNEL).setMethodCallHandler { call, result ->
            Log.d("MainActivity", "[TORRENT_CHANNEL] Method called: ${call.method}")
            when (call.method) {
                "startTorrent" -> {
                    val magnetUri = call.argument<String>("magnetUri")
                    val savePath = call.argument<String>("savePath")
                    if (magnetUri != null) {
                        val customDir = if (savePath != null) File(savePath) else null
                        TorrentEngine.startTorrent(magnetUri, customDir)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "magnetUri is required", null)
                    }
                }
                "stopTorrent" -> {
                    TorrentEngine.stopTorrent()
                    result.success(true)
                }
                "getStatus" -> {
                    val status = TorrentEngine.getStatus()
                    result.success(status)
                }
                "isMetadataReceived" -> {
                    result.success(TorrentEngine.metadataReceived)
                }
                "verifyFileReady" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val readyState = TorrentEngine.checkFileReady(filePath)
                        result.success(readyState)
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            intent.data?.let { uri ->
                if (uri.scheme == "magnet") {
                    pendingMagnetLink = uri.toString()
                }
            }
        }
    }
}
