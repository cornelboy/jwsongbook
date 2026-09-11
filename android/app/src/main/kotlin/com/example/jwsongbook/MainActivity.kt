package com.example.jwsongbook

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val overlayChannel = "com.example.jwsongbook/overlay"
    private var overlayMethodChannel: MethodChannel? = null
    private var overlayReceiverRegistered = false
    private var pendingOpenPlayer = false
    private val overlayCommandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                LyricsOverlayService.ACTION_TOGGLE_PLAY_PAUSE -> {
                    overlayMethodChannel?.invokeMethod("togglePlayPause", null)
                }
                LyricsOverlayService.ACTION_CLOSE_BUBBLE -> {
                    overlayMethodChannel?.invokeMethod("closeBubble", null)
                }
                LyricsOverlayService.ACTION_OPEN_PLAYER -> {
                    dispatchOpenPlayer()
                }
                LyricsOverlayService.ACTION_EXPANDED_CHANGED -> {
                    overlayMethodChannel?.invokeMethod(
                        "expandedChanged",
                        intent.getBooleanExtra(LyricsOverlayService.EXTRA_EXPANDED, false)
                    )
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureOpenPlayerIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isOpenPlayerIntent(intent)) {
            dispatchOpenPlayer()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overlayChannel)
        overlayMethodChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }
                    "consumePendingOpenPlayer" -> {
                        val shouldOpen = pendingOpenPlayer || isOpenPlayerIntent(intent)
                        pendingOpenPlayer = false
                        intent?.removeExtra(LyricsOverlayService.EXTRA_OVERLAY_COMMAND)
                        result.success(shouldOpen)
                    }
                    "openOverlaySettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    "showBubble" -> {
                        if (!Settings.canDrawOverlays(this)) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(this, LyricsOverlayService::class.java).apply {
                            action = LyricsOverlayService.ACTION_SHOW
                            putOverlayExtras(call.arguments as? Map<*, *>)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "updateBubble" -> {
                        if (!Settings.canDrawOverlays(this)) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(this, LyricsOverlayService::class.java).apply {
                            action = LyricsOverlayService.ACTION_UPDATE
                            putOverlayExtras(call.arguments as? Map<*, *>)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "hideBubble" -> {
                        val intent = Intent(this, LyricsOverlayService::class.java).apply {
                            action = LyricsOverlayService.ACTION_HIDE
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "collapseBubble" -> {
                        val intent = Intent(this, LyricsOverlayService::class.java).apply {
                            action = LyricsOverlayService.ACTION_COLLAPSE
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "setOverlaySuppressed" -> {
                        val intent = Intent(this, LyricsOverlayService::class.java).apply {
                            action = LyricsOverlayService.ACTION_SET_OVERLAY_SUPPRESSED
                            putExtra(
                                LyricsOverlayService.EXTRA_OVERLAY_SUPPRESSED,
                                call.arguments as? Boolean ?: false,
                            )
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        registerOverlayReceiver()
    }

    override fun onDestroy() {
        if (overlayReceiverRegistered) {
            unregisterReceiver(overlayCommandReceiver)
            overlayReceiverRegistered = false
        }
        overlayMethodChannel = null
        super.onDestroy()
    }

    private fun registerOverlayReceiver() {
        if (overlayReceiverRegistered) return

        val filter = IntentFilter().apply {
            addAction(LyricsOverlayService.ACTION_TOGGLE_PLAY_PAUSE)
            addAction(LyricsOverlayService.ACTION_CLOSE_BUBBLE)
            addAction(LyricsOverlayService.ACTION_OPEN_PLAYER)
            addAction(LyricsOverlayService.ACTION_EXPANDED_CHANGED)
        }
        ContextCompat.registerReceiver(
            this,
            overlayCommandReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        overlayReceiverRegistered = true
    }

    private fun captureOpenPlayerIntent(intent: Intent?) {
        if (isOpenPlayerIntent(intent)) {
            pendingOpenPlayer = true
        }
    }

    private fun dispatchOpenPlayer() {
        val channel = overlayMethodChannel
        if (channel == null) {
            pendingOpenPlayer = true
            return
        }
        channel.invokeMethod("openPlayer", null)
    }

    private fun isOpenPlayerIntent(intent: Intent?): Boolean {
        return intent?.getStringExtra(LyricsOverlayService.EXTRA_OVERLAY_COMMAND) ==
            LyricsOverlayService.OVERLAY_COMMAND_OPEN_PLAYER
    }

    private fun Intent.putOverlayExtras(arguments: Map<*, *>?) {
        putExtra(LyricsOverlayService.EXTRA_NUMBER, arguments?.get("number") as? String)
        putExtra(LyricsOverlayService.EXTRA_TITLE, arguments?.get("title") as? String)
        putExtra(LyricsOverlayService.EXTRA_LINE, arguments?.get("line") as? String)
        putExtra(LyricsOverlayService.EXTRA_NEXT_LINE, arguments?.get("nextLine") as? String)
        val lyricRows = (arguments?.get("lyricLines") as? List<*>)
            ?.filterIsInstance<String>()
        putStringArrayListExtra(
            LyricsOverlayService.EXTRA_LYRIC_LINES,
            lyricRows?.let { ArrayList(it) }
        )
        putExtra(LyricsOverlayService.EXTRA_POSITION_MS, arguments.intArg("positionMs"))
        putExtra(LyricsOverlayService.EXTRA_DURATION_MS, arguments.intArg("durationMs"))
        putExtra(LyricsOverlayService.EXTRA_PLAYING, arguments?.get("playing") as? Boolean ?: false)
        putExtra(LyricsOverlayService.EXTRA_CAN_CONTROL, arguments?.get("canControl") as? Boolean ?: false)
        putExtra(LyricsOverlayService.EXTRA_DARK_THEME, arguments?.get("darkTheme") as? Boolean ?: true)
    }

    private fun Map<*, *>?.intArg(key: String): Int {
        return when (val value = this?.get(key)) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            else -> 0
        }
    }
}
