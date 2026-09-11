package com.example.jwsongbook

import android.app.Service
import android.content.ComponentName
import android.content.Intent
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import com.ryanheise.audioservice.AudioService

class LyricsOverlayService : Service() {
    private var windowManager: WindowManager? = null
    // The bubble and expanded panel use independent overlay windows. Android
    // otherwise animates a resize/reposition differently at each screen edge.
    private var rootView: FrameLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var panelRootView: FrameLayout? = null
    private var panelLayoutParams: WindowManager.LayoutParams? = null
    private var closeTargetView: FrameLayout? = null
    private var closeTargetParams: WindowManager.LayoutParams? = null
    private var expanded = false
    private var isPanelTransitioning = false
    private var animatePanelEntrance = false
    private var animateBubbleEntrance = false
    private var songNumber = ""
    private var songTitle = "JW Songs"
    private var currentLine = "Waiting for lyrics"
    private var lyricLines: List<OverlayLyricLine> = emptyList()
    private var basePositionMs = 0
    private var baseRealtimeMs = 0L
    private var durationMs = 0
    private var playing = false
    private var canControl = false
    private var darkTheme = true
    private var buttonX = Int.MIN_VALUE
    private var buttonY = Int.MIN_VALUE
    private var initialButtonX = 0
    private var initialButtonY = 0
    private var initialRootX = 0
    private var initialRootY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var moved = false
    private var dragging = false
    private var overCloseTarget = false
    private var overlaySuppressed = true
    private var mediaBrowser: MediaBrowserCompat? = null
    private var mediaController: MediaControllerCompat? = null
    private val syncHandler = Handler(Looper.getMainLooper())
    private val mediaControllerCallback = object : MediaControllerCompat.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackStateCompat?) {
            syncHandler.post { applyMediaPlaybackState(state) }
        }

        override fun onSessionDestroyed() {
            syncHandler.post {
                clearMediaController()
                mediaBrowser?.disconnect()
                mediaBrowser = null
                connectMediaSession()
            }
        }
    }
    private val mediaConnectionCallback = object : MediaBrowserCompat.ConnectionCallback() {
        override fun onConnected() {
            val token = mediaBrowser?.sessionToken ?: return
            clearMediaController()
            mediaController = MediaControllerCompat(this@LyricsOverlayService, token).also {
                it.registerCallback(mediaControllerCallback)
                applyMediaPlaybackState(it.playbackState)
            }
        }

        override fun onConnectionSuspended() {
            clearMediaController()
        }

        override fun onConnectionFailed() {
            clearMediaController()
        }
    }
    private val syncRunnable = object : Runnable {
        override fun run() {
            val lineChanged = updateCurrentLineFromTimeline()
            if (expanded && lineChanged && !dragging && !isPanelTransitioning) render()
            if (playing && lyricLines.isNotEmpty()) {
                syncHandler.postDelayed(this, overlaySyncIntervalMs)
            }
        }
    }
    private val dimBubbleRunnable = Runnable {
        if (!overlaySuppressed && !expanded && !dragging) {
            rootView?.getChildAt(0)?.animate()
                ?.alpha(idleBubbleAlpha)
                ?.setDuration(bubbleDimDurationMs)
                ?.start()
        }
    }

    private data class OverlayLyricLine(
        val startMs: Int,
        val endMs: Int,
        val text: String,
    )

    private data class ExpandedLayout(
        val panelX: Int,
        val panelY: Int,
        val panelWidth: Int,
        val panelHeight: Int,
        val rootX: Int,
        val rootY: Int,
        val rootWidth: Int,
        val rootHeight: Int,
    )

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        connectMediaSession()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        connectMediaSession()
        when (intent?.action) {
            ACTION_SHOW, ACTION_UPDATE -> {
                updateState(intent)
                showOrUpdate()
            }
            ACTION_HIDE -> {
                hideBubble()
                stopSelf()
            }
            ACTION_COLLAPSE -> {
                collapseBubble()
            }
            ACTION_SET_OVERLAY_SUPPRESSED -> {
                setOverlaySuppressed(
                    intent.getBooleanExtra(EXTRA_OVERLAY_SUPPRESSED, false),
                )
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        clearMediaController()
        mediaBrowser?.disconnect()
        mediaBrowser = null
        hideBubble()
        super.onDestroy()
    }

    private fun updateState(intent: Intent) {
        songNumber = intent.getStringExtra(EXTRA_NUMBER) ?: songNumber
        songTitle = intent.getStringExtra(EXTRA_TITLE) ?: songTitle
        lyricLines = parseLyricLines(intent.getStringArrayListExtra(EXTRA_LYRIC_LINES))
        basePositionMs = intent.getIntExtra(EXTRA_POSITION_MS, currentPlaybackPositionMs())
        durationMs = intent.getIntExtra(EXTRA_DURATION_MS, durationMs)
        baseRealtimeMs = SystemClock.elapsedRealtime()
        currentLine = intent.getStringExtra(EXTRA_LINE) ?: currentLine
        playing = intent.getBooleanExtra(EXTRA_PLAYING, playing)
        canControl = intent.getBooleanExtra(EXTRA_CAN_CONTROL, canControl)
        darkTheme = intent.getBooleanExtra(EXTRA_DARK_THEME, darkTheme)
        updateCurrentLineFromTimeline()
        restartNativeSync()
    }

    private fun showOrUpdate() {
        if (!Settings.canDrawOverlays(this)) return
        windowManager = windowManager ?: getSystemService(WINDOW_SERVICE) as WindowManager

        if (!dragging && !isPanelTransitioning) render()
    }

    private fun render() {
        if (overlaySuppressed) {
            removeSuppressedOverlayWindows()
            return
        }
        ensureButtonPosition()
        if (expanded) {
            renderPanel()
        } else {
            renderBubble()
        }
    }

    private fun renderBubble() {
        val root = ensureBubbleWindow() ?: return
        val params = layoutParams ?: return
        root.removeAllViews()
        params.width = touchSize
        params.height = touchSize
        params.x = buttonTouchX()
        params.y = buttonTouchY()
        val buttonWrapper = touchWrappedButton(params.x, params.y)
        root.addView(buttonWrapper)
        safeUpdateBubbleLayout()
        if (animateBubbleEntrance) {
            animateBubbleEntrance = false
            val bubbleButton = (buttonWrapper as? FrameLayout)?.getChildAt(0)
            bubbleButton?.post { animateBubbleIn(bubbleButton) }
        }
        scheduleBubbleDim()
    }

    private fun renderPanel() {
        val width = currentPanelWidth()
        val panel = expandedPanel()
        panel.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val panelHeight = panel.measuredHeight
            .coerceAtLeast(160.dp)
            .coerceAtMost(screenHeight() - (edgePadding * 2))
        val root = panelRootView ?: FrameLayout(this).also { panelRootView = it }
        val existingParams = panelLayoutParams
        val layout = if (existingParams == null) {
            expandedLayout(width, panelHeight)
        } else {
            ExpandedLayout(
                panelX = clampX(existingParams.x, width),
                panelY = clampY(existingParams.y, panelHeight),
                panelWidth = width,
                panelHeight = panelHeight,
                rootX = existingParams.x,
                rootY = existingParams.y,
                rootWidth = width,
                rootHeight = panelHeight,
            )
        }
        val params = existingParams ?: WindowManager.LayoutParams(
            layout.panelWidth,
            layout.panelHeight,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }.also {
            panelLayoutParams = it
            safeAddView(root, it)
        }

        root.removeAllViews()
        params.width = layout.panelWidth
        params.height = layout.panelHeight
        params.x = layout.panelX
        params.y = layout.panelY
        root.addView(
            panel,
            FrameLayout.LayoutParams(layout.panelWidth, layout.panelHeight),
        )
        safeUpdatePanelLayout()

        if (expanded && animatePanelEntrance) {
            animatePanelEntrance = false
            preparePanelEntrance(panel)
            panel.post { animatePanelIn(panel) }
        }
    }

    private fun ensureBubbleWindow(): FrameLayout? {
        rootView?.let { return it }
        val params = WindowManager.LayoutParams(
            touchSize,
            touchSize,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = buttonTouchX()
            y = buttonTouchY()
        }
        val root = FrameLayout(this)
        layoutParams = params
        rootView = root
        safeAddView(root, params)
        return root
    }

    private fun touchWrappedButton(wrapperScreenX: Int, wrapperScreenY: Int): View {
        return FrameLayout(this).apply {
            isClickable = true
            installDragHandler(this) {
                toggleExpanded()
            }
            val visibleLeft = (buttonX - wrapperScreenX).coerceIn(0, touchSize - buttonSize)
            val visibleTop = (buttonY - wrapperScreenY).coerceIn(0, touchSize - buttonSize)
            val button = collapsedButton()
            addView(
                button,
                FrameLayout.LayoutParams(buttonSize, buttonSize).apply {
                    leftMargin = visibleLeft
                    topMargin = visibleTop
                },
            )
        }
    }

    private fun expandedLayout(panelWidth: Int, panelHeight: Int): ExpandedLayout {
        val rightSide = buttonX + (buttonSize / 2) >= screenWidth() / 2
        val panelX = if (rightSide) {
            clampX(screenWidth() - panelWidth - panelEdgeInset, panelWidth)
        } else {
            clampX(panelEdgeInset, panelWidth)
        }
        val panelY = clampY(buttonY - panelYOffset, panelHeight)

        return ExpandedLayout(
            panelX = panelX,
            panelY = panelY,
            panelWidth = panelWidth,
            panelHeight = panelHeight,
            rootX = panelX,
            rootY = panelY,
            rootWidth = panelWidth,
            rootHeight = panelHeight,
        )
    }

    private fun updateExpandedLayoutDuringDrag(dx: Int, dy: Int) {
        val root = panelRootView ?: return
        val params = panelLayoutParams ?: return
        val panel = root.getChildAt(0) ?: return
        val panelParams = panel.layoutParams as? FrameLayout.LayoutParams ?: return
        val panelWidth = panelParams.width.takeIf { it > 0 } ?: currentPanelWidth()
        val panelHeight = panelParams.height
            .takeIf { it > 0 }
            ?: panel.measuredHeight.coerceAtLeast(160.dp)
        // The panel is already the overlay root. Moving that root directly keeps
        // the drag stable instead of recalculating it from the hidden bubble.
        params.x = clampX(initialRootX + dx, panelWidth)
        params.y = clampY(initialRootY + dy, panelHeight)

        // Keep the collapsed bubble associated with the nearest screen edge.
        // This only affects the next collapse animation; it never changes the
        // expanded panel's position while the user is dragging it.
        buttonX = if (params.x + (panelWidth / 2) >= screenWidth() / 2) {
            screenWidth() - buttonSize
        } else {
            0
        }
        buttonY = clampButtonY(params.y + panelYOffset)
        safeUpdatePanelLayout()
    }

    private fun toggleExpanded() {
        setExpanded(!expanded)
    }

    private fun setExpanded(value: Boolean) {
        if (expanded == value || isPanelTransitioning) return
        if (!value) {
            animatePanelOut()
            return
        }

        isPanelTransitioning = true
        expanded = true
        animatePanelEntrance = true
        sendExpandedChanged(true)
        render()
        animateBubbleOut()
    }

    private fun animateBubbleOut() {
        val wrapper = rootView?.getChildAt(0) as? FrameLayout
        val bubble = wrapper?.getChildAt(0)
        if (bubble == null) {
            removeBubbleWindow()
            return
        }

        bubble.animate()
            .alpha(0f)
            .scaleX(bubbleScaleStart)
            .scaleY(bubbleScaleStart)
            .setDuration(bubbleCloseDurationMs)
            .setInterpolator(panelInterpolator)
            .withEndAction { removeBubbleWindow() }
            .start()
    }

    private fun animatePanelIn(panel: View) {
        panel.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(panelOpenDurationMs)
            .setInterpolator(panelInterpolator)
            .withEndAction { isPanelTransitioning = false }
            .start()
    }

    private fun preparePanelEntrance(panel: View) {
        panel.pivotX = panel.width / 2f
        panel.pivotY = panel.height / 2f
        panel.alpha = 0f
        panel.scaleX = panelScaleStart
        panel.scaleY = panelScaleStart
    }

    private fun animatePanelOut() {
        val panel = panelRootView?.getChildAt(0)
        if (panel == null) {
            completePanelCollapse()
            return
        }

        isPanelTransitioning = true
        animateBubbleEntrance = true
        renderBubble()
        panel.pivotX = panel.width / 2f
        panel.pivotY = panel.height / 2f
        panel.animate()
            .alpha(0f)
            .scaleX(panelScaleStart)
            .scaleY(panelScaleStart)
            .setDuration(panelCloseDurationMs)
            .setInterpolator(panelInterpolator)
            .withEndAction { completePanelCollapse() }
            .start()
    }

    private fun completePanelCollapse() {
        removePanelWindow()
        expanded = false
        isPanelTransitioning = false
        sendExpandedChanged(false)
    }

    private fun animateBubbleIn(button: View) {
        button.alpha = 0f
        button.scaleX = bubbleScaleStart
        button.scaleY = bubbleScaleStart
        button.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(bubbleOpenDurationMs)
            .setInterpolator(panelInterpolator)
            .start()
    }

    private fun collapsedButton(): View {
        return FrameLayout(this).apply {
            background = oval(
                Color.parseColor("#2B1F37"),
                Color.parseColor("#C291FF"),
                1.dp,
            )
            elevation = 6.dp.toFloat()
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setOval(0, 0, view.width, view.height)
                }
            }
            contentDescription = "Show lyrics"
            addView(
                TextView(context).apply {
                    text = getString(R.string.floating_lyrics_bubble_label)
                    textSize = 10.5f
                    typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                    setTextColor(Color.parseColor("#E6F2EDF5"))
                    includeFontPadding = false
                    gravity = Gravity.CENTER
                },
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }

    private fun expandedPanel(): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            // Any non-interactive space on the panel can move it. Buttons still
            // consume their own gestures, preserving reliable play/close taps.
            installDragHandler(this)
            background = roundedRect(
                color = cardColor,
                strokeColor = withAlpha(primaryColor, 70),
                strokeWidth = 1.dp,
                radius = 8.dp,
            )
            elevation = 18f
            setPadding(14.dp, 12.dp, 10.dp, 12.dp)

            addView(headerRow())
            addView(space(12.dp))
            addView(lyricPreview())
            addView(space(12.dp))
            addView(actionRow())
        }
    }

    private fun headerRow(): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            installDragHandler(this)

            addView(
                TextView(context).apply {
                    text = songNumber.ifBlank { "---" }
                    gravity = Gravity.CENTER
                    setTextColor(primaryColor)
                    textSize = 14f
                    applyAppFont(Typeface.BOLD)
                    background = roundedRect(
                        color = withAlpha(primaryColor, 36),
                        strokeColor = withAlpha(primaryColor, 100),
                        strokeWidth = 1.dp,
                        radius = 8.dp,
                    )
                },
                LinearLayout.LayoutParams(38.dp, 38.dp),
            )

            addView(
                TextView(context).apply {
                    text = songTitle
                    gravity = Gravity.CENTER_VERTICAL
                    setTextColor(textHighColor)
                    textSize = 14f
                    applyAppFont(Typeface.BOLD)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                    setPadding(10.dp, 0, 8.dp, 0)
                },
                LinearLayout.LayoutParams(0, 38.dp, 1f),
            )

            addView(
                ImageButton(context).apply {
                    setImageResource(R.drawable.ic_overlay_close)
                    setColorFilter(textMediumColor)
                    setBackgroundColor(Color.TRANSPARENT)
                    contentDescription = "Close lyrics"
                    setPadding(8.dp, 8.dp, 8.dp, 8.dp)
                    setOnClickListener {
                        setExpanded(false)
                    }
                },
                LinearLayout.LayoutParams(34.dp, 34.dp),
            )
        }
    }

    private fun lyricPreview(): View {
        val text = currentLine.ifBlank { "Waiting for lyrics" }
        val isWaiting = text == "Waiting for lyrics"

        return if (isWaiting) {
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                installDragHandler(this)
                setPadding(16.dp, 16.dp, 16.dp, 16.dp)
                background = roundedRect(
                    color = cardColor,
                    strokeColor = dividerColor,
                    strokeWidth = 1.dp,
                    radius = 8.dp,
                )
                addView(
                    ImageView(context).apply {
                        setImageResource(R.drawable.ic_overlay_lyrics)
                        setColorFilter(textMediumColor)
                    },
                    LinearLayout.LayoutParams(24.dp, 24.dp),
                )
                addView(
                    TextView(context).apply {
                        this.text = text
                        setTextColor(textHighColor)
                        textSize = 14f
                        applyAppFont()
                        setPadding(12.dp, 0, 0, 0)
                    },
                    LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
                )
            }
        } else {
            TextView(this).apply {
                installDragHandler(this)
                this.text = text
                setTextColor(primaryColor)
                textSize = if (text.length > 70) 20f else 22f
                applyAppFont(Typeface.BOLD)
                setLineSpacing(0f, 1.15f)
                maxLines = 3
                ellipsize = TextUtils.TruncateAt.END
                setPadding(0, 8.dp, 0, 8.dp)
            }
        }
    }

    private fun actionRow(): View {
        return LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            installDragHandler(this)

            addView(
                ImageButton(context).apply {
                    setImageResource(
                        if (playing) R.drawable.ic_overlay_pause else R.drawable.ic_overlay_play,
                    )
                    setColorFilter(onPrimaryColor)
                    background = oval(primaryColor, Color.TRANSPARENT, 0)
                    alpha = if (canControl) 1f else 0.45f
                    isEnabled = canControl
                    contentDescription = if (!canControl) {
                        "Play a song first"
                    } else if (playing) {
                        "Pause"
                    } else {
                        "Play"
                    }
                    setPadding(12.dp, 12.dp, 12.dp, 12.dp)
                    setOnClickListener { dispatchPlayPause() }
                },
                LinearLayout.LayoutParams(48.dp, 48.dp),
            )

            addView(View(context), LinearLayout.LayoutParams(0, 1, 1f))

            addView(
                ImageButton(context).apply {
                    setImageResource(R.drawable.ic_overlay_open_full)
                    setColorFilter(textHighColor)
                    background = oval(Color.TRANSPARENT, outlineColor, 1.dp)
                    contentDescription = "Open full player"
                    setPadding(12.dp, 12.dp, 12.dp, 12.dp)
                    setOnClickListener { openPlayer() }
                },
                LinearLayout.LayoutParams(42.dp, 42.dp),
            )
        }
    }

    private fun installDragHandler(view: View, onTap: (() -> Unit)? = null) {
        if (onTap != null) {
            view.setOnClickListener { onTap() }
        }
        view.setOnTouchListener { _, event ->
            if (isPanelTransitioning) return@setOnTouchListener true
            val params = (if (expanded) panelLayoutParams else layoutParams)
                ?: return@setOnTouchListener false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    syncHandler.removeCallbacks(dimBubbleRunnable)
                    if (!expanded) {
                        view.animate().cancel()
                        view.alpha = 1f
                    }
                    moved = false
                    dragging = true
                    overCloseTarget = false
                    ensureButtonPosition()
                    initialButtonX = buttonX
                    initialButtonY = buttonY
                    initialRootX = params.x
                    initialRootY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (kotlin.math.abs(dx) > touchSlop || kotlin.math.abs(dy) > touchSlop) {
                        moved = true
                        showCloseTarget()
                    }
                    if (expanded) {
                        updateExpandedLayoutDuringDrag(dx, dy)
                    } else {
                        buttonX = clampButtonX(initialButtonX + dx)
                        buttonY = clampButtonY(initialButtonY + dy)
                        params.x = buttonTouchX()
                        params.y = buttonTouchY()
                        safeUpdateBubbleLayout()
                        updateCollapsedButtonPlacement(view)
                    }
                    updateCloseTarget(isDragOverCloseTarget())
                    true
                }
                MotionEvent.ACTION_UP -> {
                    dragging = false
                    if (moved) {
                        val shouldClose = isDragOverCloseTarget()
                        hideCloseTarget()
                        if (shouldClose) {
                            requestBubbleClose()
                            return@setOnTouchListener true
                        }
                        if (!expanded) {
                            snapButtonToNearestSide()
                            params.x = buttonTouchX()
                            params.y = buttonTouchY()
                            safeUpdateBubbleLayout()
                            updateCollapsedButtonPlacement(view)
                            scheduleBubbleDim()
                        }
                        saveButtonPosition()
                    } else if (!moved) {
                        hideCloseTarget()
                        view.performClick()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    dragging = false
                    hideCloseTarget()
                    if (moved) {
                        if (!expanded) {
                            snapButtonToNearestSide()
                            params.x = buttonTouchX()
                            params.y = buttonTouchY()
                            safeUpdateBubbleLayout()
                            updateCollapsedButtonPlacement(view)
                            scheduleBubbleDim()
                        }
                        saveButtonPosition()
                    } else if (!expanded) {
                        scheduleBubbleDim()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun hideBubble() {
        hideCloseTarget()
        syncHandler.removeCallbacks(syncRunnable)
        syncHandler.removeCallbacks(dimBubbleRunnable)
        removeBubbleWindow()
        removePanelWindow()
        if (expanded) {
            expanded = false
            sendExpandedChanged(false)
        }
    }

    private fun setOverlaySuppressed(value: Boolean) {
        if (overlaySuppressed == value) return
        overlaySuppressed = value
        if (value) {
            removeSuppressedOverlayWindows()
        } else if (Settings.canDrawOverlays(this)) {
            render()
        }
    }

    private fun removeSuppressedOverlayWindows() {
        hideCloseTarget()
        syncHandler.removeCallbacks(dimBubbleRunnable)
        removeBubbleWindow()
        removePanelWindow()
        if (expanded) {
            expanded = false
            isPanelTransitioning = false
            sendExpandedChanged(false)
        }
    }

    private fun scheduleBubbleDim() {
        syncHandler.removeCallbacks(dimBubbleRunnable)
        if (!overlaySuppressed && !expanded) {
            syncHandler.postDelayed(dimBubbleRunnable, bubbleIdleDelayMs)
        }
    }

    private fun collapseBubble() {
        if (!expanded) return
        setExpanded(false)
    }

    private fun openPlayer() {
        setExpanded(false)
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent != null) {
            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
            intent.putExtra(EXTRA_OVERLAY_COMMAND, OVERLAY_COMMAND_OPEN_PLAYER)
            startActivity(intent)
        }
        sendOverlayCommand(ACTION_OPEN_PLAYER)
    }

    private fun dispatchPlayPause() {
        if (!canControl) return
        basePositionMs = currentPlaybackPositionMs()
        baseRealtimeMs = SystemClock.elapsedRealtime()
        playing = !playing
        requestRender()
        restartNativeSync()

        val controller = mediaController
        if (controller == null) {
            sendOverlayCommand(ACTION_TOGGLE_PLAY_PAUSE)
        } else if (playing) {
            controller.transportControls.play()
        } else {
            controller.transportControls.pause()
        }
    }

    private fun requestBubbleClose() {
        sendOverlayCommand(ACTION_CLOSE_BUBBLE)
        hideBubble()
        stopSelf()
    }

    private fun sendOverlayCommand(action: String) {
        sendBroadcast(Intent(action).apply { setPackage(packageName) })
    }

    private fun sendExpandedChanged(value: Boolean) {
        sendBroadcast(
            Intent(ACTION_EXPANDED_CHANGED).apply {
                setPackage(packageName)
                putExtra(EXTRA_EXPANDED, value)
            },
        )
    }

    private fun requestRender(force: Boolean = false) {
        syncHandler.post {
            val hasOverlay = rootView != null || panelRootView != null
            if (hasOverlay && (force || !isPanelTransitioning)) {
                render()
            }
        }
    }

    private fun safeAddView(view: View?, params: WindowManager.LayoutParams?) {
        if (view == null || params == null) return
        try {
            windowManager?.addView(view, params)
        } catch (ignored: RuntimeException) {
        }
    }

    private fun safeUpdateBubbleLayout() {
        val view = rootView ?: return
        val params = layoutParams ?: return
        try {
            windowManager?.updateViewLayout(view, params)
        } catch (ignored: RuntimeException) {
        }
    }

    private fun safeUpdatePanelLayout() {
        val view = panelRootView ?: return
        val params = panelLayoutParams ?: return
        try {
            windowManager?.updateViewLayout(view, params)
        } catch (ignored: RuntimeException) {
        }
    }

    private fun removeBubbleWindow() {
        val view = rootView ?: return
        safeRemoveView(view)
        rootView = null
        layoutParams = null
    }

    private fun removePanelWindow() {
        val view = panelRootView ?: return
        safeRemoveView(view)
        panelRootView = null
        panelLayoutParams = null
    }

    private fun safeRemoveView(view: View?) {
        if (view == null) return
        try {
            windowManager?.removeView(view)
        } catch (ignored: RuntimeException) {
        }
    }

    private fun restartNativeSync() {
        syncHandler.removeCallbacks(syncRunnable)
        if (playing && lyricLines.isNotEmpty()) {
            syncHandler.postDelayed(syncRunnable, overlaySyncIntervalMs)
        }
    }

    private fun connectMediaSession() {
        if (mediaBrowser?.isConnected == true) return

        mediaBrowser?.disconnect()
        mediaBrowser = MediaBrowserCompat(
            this,
            ComponentName(this, AudioService::class.java),
            mediaConnectionCallback,
            null,
        ).also { it.connect() }
    }

    private fun clearMediaController() {
        mediaController?.unregisterCallback(mediaControllerCallback)
        mediaController = null
    }

    private fun applyMediaPlaybackState(state: PlaybackStateCompat?) {
        if (state == null) return

        val wasPlaying = playing
        playing = when (state.state) {
            PlaybackStateCompat.STATE_PLAYING,
            PlaybackStateCompat.STATE_BUFFERING,
            PlaybackStateCompat.STATE_CONNECTING -> true
            else -> false
        }

        if (state.position >= 0L) {
            basePositionMs = state.position.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
            baseRealtimeMs = state.lastPositionUpdateTime.takeIf { it > 0L }
                ?: SystemClock.elapsedRealtime()
        }

        updateCurrentLineFromTimeline()
        restartNativeSync()
        if (playing != wasPlaying && !dragging) requestRender()
    }

    private fun updateCurrentLineFromTimeline(): Boolean {
        if (lyricLines.isEmpty()) return false

        val position = currentPlaybackPositionMs() + lyricLeadMs
        val activeLine = lyricLines.asReversed().firstOrNull {
            position >= it.startMs && position < it.endMs
        }
        val nextLine = lyricLines.firstOrNull { it.startMs > position }
        val nextText = (activeLine ?: nextLine ?: lyricLines.last()).text
        if (currentLine == nextText) return false
        currentLine = nextText
        return true
    }

    private fun currentPlaybackPositionMs(): Int {
        if (!playing) return basePositionMs

        val elapsedMs = (SystemClock.elapsedRealtime() - baseRealtimeMs).coerceAtLeast(0L)
        val estimated = basePositionMs.toLong() + elapsedMs
        val max = durationMs.takeIf { it > 0 } ?: Int.MAX_VALUE
        return estimated.coerceIn(0L, max.toLong()).toInt()
    }

    private fun parseLyricLines(rows: ArrayList<String>?): List<OverlayLyricLine> {
        if (rows == null) return emptyList()
        return rows.mapNotNull { row ->
            val parts = row.split('\t', limit = 3)
            if (parts.size < 3) return@mapNotNull null
            val startMs = parts[0].toIntOrNull() ?: return@mapNotNull null
            val endMs = parts[1].toIntOrNull() ?: return@mapNotNull null
            val text = parts[2].trim()
            if (text.isBlank()) return@mapNotNull null
            OverlayLyricLine(startMs, endMs, text)
        }
    }

    private fun space(height: Int): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(1, height)
        }
    }

    private fun roundedRect(
        color: Int,
        strokeColor: Int,
        strokeWidth: Int,
        radius: Int,
    ): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = radius.toFloat()
            if (strokeWidth > 0) setStroke(strokeWidth, strokeColor)
        }
    }

    private fun oval(color: Int, strokeColor: Int, strokeWidth: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
            if (strokeWidth > 0) setStroke(strokeWidth, strokeColor)
        }
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    private val cardColor: Int
        get() = Color.parseColor(if (darkTheme) "#242424" else "#E9E7EC")

    private val primaryColor: Int
        get() = Color.parseColor(if (darkTheme) "#BB86FC" else "#6D3AA8")

    // Matches Flutter's ColorScheme.onPrimary for the circular player control.
    private val onPrimaryColor: Int
        get() = Color.parseColor(if (darkTheme) "#121212" else "#FFFFFF")

    private val textHighColor: Int
        get() = Color.parseColor(if (darkTheme) "#DEFFFFFF" else "#1C1B1F")

    private val textMediumColor: Int
        get() = Color.parseColor(if (darkTheme) "#99FFFFFF" else "#49454F")

    private val dividerColor: Int
        get() = Color.parseColor(if (darkTheme) "#1FFFFFFF" else "#CAC4D0")

    private val outlineColor: Int
        get() = Color.parseColor(if (darkTheme) "#66FFFFFF" else "#79747E")

    private val errorColor: Int
        get() = Color.parseColor(if (darkTheme) "#CF6679" else "#B3261E")

    private fun TextView.applyAppFont(style: Int = Typeface.NORMAL) {
        // Flutter renders the rest of the app in Roboto; do not inherit a
        // device-selected display font for this native Android overlay.
        typeface = Typeface.create("Roboto", style)
        includeFontPadding = true
    }

    private fun screenWidth(): Int = resources.displayMetrics.widthPixels

    private fun screenHeight(): Int = resources.displayMetrics.heightPixels

    private fun ensureButtonPosition() {
        if (buttonX != Int.MIN_VALUE && buttonY != Int.MIN_VALUE) return
        val saved = savedButtonPosition()
        if (saved != null) {
            buttonX = clampButtonX(saved.first)
            buttonY = clampButtonY(saved.second)
            return
        }
        val defaultY = (screenHeight() * 0.48f).toInt()
        buttonX = 0
        buttonY = clampButtonY(defaultY)
    }

    private fun savedButtonPosition(): Pair<Int, Int>? {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        if (!prefs.contains(PREF_BUTTON_X) || !prefs.contains(PREF_BUTTON_Y)) return null
        return prefs.getInt(PREF_BUTTON_X, 0) to prefs.getInt(PREF_BUTTON_Y, 0)
    }

    private fun saveButtonPosition() {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putInt(PREF_BUTTON_X, buttonX)
            .putInt(PREF_BUTTON_Y, buttonY)
            .apply()
    }

    private fun clampX(value: Int, width: Int): Int {
        val max = screenWidth() - width - edgePadding
        if (max < edgePadding) return 0
        return value.coerceIn(edgePadding, max)
    }

    private fun clampY(value: Int, height: Int): Int {
        val max = screenHeight() - height - edgePadding
        if (max < edgePadding) return 0
        return value.coerceIn(edgePadding, max)
    }

    private fun buttonTouchX(): Int {
        val max = screenWidth() - touchSize
        return (buttonX - touchInset).coerceIn(0, max.coerceAtLeast(0))
    }

    private fun buttonTouchY(): Int {
        val max = screenHeight() - touchSize
        return (buttonY - touchInset).coerceIn(0, max.coerceAtLeast(0))
    }

    private fun clampButtonX(value: Int): Int {
        val max = screenWidth() - buttonSize
        return value.coerceIn(0, max)
    }

    private fun clampButtonY(value: Int): Int {
        val max = screenHeight() - buttonSize - edgePadding
        return value.coerceIn(edgePadding, max)
    }

    private fun snapButtonToNearestSide() {
        val snapRight = buttonX + (buttonSize / 2) >= screenWidth() / 2
        buttonX = if (snapRight) screenWidth() - buttonSize else 0
        buttonY = clampButtonY(buttonY)
    }

    private fun updateCollapsedButtonPlacement(wrapper: View) {
        val rootParams = layoutParams ?: return
        val frame = wrapper as? FrameLayout ?: return
        val button = frame.getChildAt(0) ?: return
        val childParams = button.layoutParams as? FrameLayout.LayoutParams ?: return
        childParams.leftMargin = (buttonX - rootParams.x).coerceIn(0, touchSize - buttonSize)
        childParams.topMargin = (buttonY - rootParams.y).coerceIn(0, touchSize - buttonSize)
        button.layoutParams = childParams
        button.animate().cancel()
        button.translationX = 0f
    }

    private fun showCloseTarget() {
        windowManager = windowManager ?: getSystemService(WINDOW_SERVICE) as WindowManager
        if (closeTargetView != null) return

        closeTargetParams = WindowManager.LayoutParams(
            closeTargetWindowSize,
            closeTargetWindowSize,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = closeTargetX()
            y = closeTargetY()
        }

        closeTargetView = FrameLayout(this).apply {
            background = null
            alpha = 0f
            scaleX = 0.85f
            scaleY = 0.85f
            addView(
                TextView(context).apply {
                    text = "X"
                    contentDescription = "Drop here to hide floating lyrics"
                    gravity = Gravity.CENTER
                    textSize = 28f
                    setTextColor(textMediumColor)
                    applyAppFont(Typeface.BOLD)
                    background = closeTargetBackground(active = false)
                },
                FrameLayout.LayoutParams(
                    closeTargetSize,
                    closeTargetSize,
                ).apply {
                    gravity = Gravity.CENTER
                },
            )
        }
        safeAddView(closeTargetView, closeTargetParams)
        closeTargetView?.animate()
            ?.alpha(1f)
            ?.scaleX(1f)
            ?.scaleY(1f)
            ?.setDuration(140)
            ?.start()
    }

    private fun updateCloseTarget(active: Boolean) {
        val target = closeTargetView ?: return
        if (overCloseTarget == active) return

        overCloseTarget = active
        val circle = target.getChildAt(0) as? TextView
        circle?.background = closeTargetBackground(active)
        circle?.setTextColor(if (active) Color.WHITE else textMediumColor)
        target.animate()
            .alpha(1f)
            .setDuration(90)
            .start()
        circle?.animate()
            ?.scaleX(if (active) 1.04f else 1f)
            ?.scaleY(if (active) 1.04f else 1f)
            ?.setDuration(90)
            ?.start()
    }

    private fun hideCloseTarget() {
        val target = closeTargetView ?: return
        closeTargetView = null
        closeTargetParams = null
        overCloseTarget = false
        target.animate()
            .alpha(0f)
            .scaleX(0.85f)
            .scaleY(0.85f)
            .setDuration(100)
            .withEndAction {
                try {
                    safeRemoveView(target)
                } catch (ignored: IllegalArgumentException) {
                }
            }
            .start()
    }

    private fun isDragOverCloseTarget(): Boolean {
        val params = if (expanded) panelLayoutParams else layoutParams
        val centerX: Int
        val centerY: Int
        if (expanded && params != null) {
            centerX = params.x + (params.width / 2)
            centerY = params.y + (params.height / 2)
        } else {
            centerX = buttonX + (buttonSize / 2)
            centerY = buttonY + (buttonSize / 2)
        }
        val dx = centerX - closeTargetCenterX()
        val dy = centerY - closeTargetCenterY()
        return (dx * dx) + (dy * dy) <= closeTargetHitRadius * closeTargetHitRadius
    }

    private fun closeTargetBackground(active: Boolean): GradientDrawable {
        return if (active) {
            oval(errorColor, Color.TRANSPARENT, 0)
        } else {
            oval(
                withAlpha(cardColor, 244),
                withAlpha(outlineColor, 170),
                1.dp,
            )
        }
    }

    private fun closeTargetCenterX(): Int = screenWidth() / 2

    private fun closeTargetCenterY(): Int =
        screenHeight() - closeTargetBottomMargin - (closeTargetSize / 2)

    private fun closeTargetX(): Int = closeTargetCenterX() - (closeTargetWindowSize / 2)

    private fun closeTargetY(): Int =
        closeTargetCenterY() - (closeTargetWindowSize / 2)

    private fun overlayWindowType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private val buttonSize: Int
        get() = 56.dp

    private val touchSize: Int
        get() = 72.dp

    private val touchInset: Int
        get() = 8.dp

    private val edgePadding: Int
        get() = 0.dp

    private val panelEdgeInset: Int
        get() = 16.dp

    private val touchSlop: Int
        get() = 18.dp

    private val closeTargetSize: Int
        get() = 56.dp

    private val closeTargetWindowSize: Int
        get() = 88.dp

    private val closeTargetBottomMargin: Int
        get() = 150.dp

    private val closeTargetHitRadius: Int
        get() = 72.dp

    private fun currentPanelWidth(): Int {
        val available = screenWidth() - (panelEdgeInset * 2)
        val min = minOf(220.dp, available)
        val max = minOf(300.dp, available)
        return max.coerceAtLeast(min)
    }

    private val panelYOffset: Int
        get() = 86.dp

    private val panelInterpolator = PathInterpolator(0.2f, 0f, 0f, 1f)

    private val Int.dp: Int
        get() = (this * resources.displayMetrics.density).toInt()

    companion object {
        const val ACTION_SHOW = "com.example.jwsongbook.overlay.SHOW"
        const val ACTION_UPDATE = "com.example.jwsongbook.overlay.UPDATE"
        const val ACTION_HIDE = "com.example.jwsongbook.overlay.HIDE"
        const val ACTION_COLLAPSE = "com.example.jwsongbook.overlay.COLLAPSE"
        const val ACTION_SET_OVERLAY_SUPPRESSED = "com.example.jwsongbook.overlay.SET_OVERLAY_SUPPRESSED"
        const val ACTION_TOGGLE_PLAY_PAUSE = "com.example.jwsongbook.overlay.TOGGLE_PLAY_PAUSE"
        const val ACTION_CLOSE_BUBBLE = "com.example.jwsongbook.overlay.CLOSE_BUBBLE"
        const val ACTION_OPEN_PLAYER = "com.example.jwsongbook.overlay.OPEN_PLAYER"
        const val ACTION_EXPANDED_CHANGED = "com.example.jwsongbook.overlay.EXPANDED_CHANGED"
        const val EXTRA_NUMBER = "number"
        const val EXTRA_TITLE = "title"
        const val EXTRA_LINE = "line"
        const val EXTRA_NEXT_LINE = "nextLine"
        const val EXTRA_LYRIC_LINES = "lyricLines"
        const val EXTRA_POSITION_MS = "positionMs"
        const val EXTRA_DURATION_MS = "durationMs"
        const val EXTRA_PLAYING = "playing"
        const val EXTRA_CAN_CONTROL = "canControl"
        const val EXTRA_DARK_THEME = "darkTheme"
        const val EXTRA_EXPANDED = "expanded"
        const val EXTRA_OVERLAY_SUPPRESSED = "overlaySuppressed"
        const val EXTRA_OVERLAY_COMMAND = "overlayCommand"
        const val OVERLAY_COMMAND_OPEN_PLAYER = "openPlayer"
        private const val PREFS_NAME = "lyrics_overlay"
        private const val PREF_BUTTON_X = "buttonX"
        private const val PREF_BUTTON_Y = "buttonY"
        private const val lyricLeadMs = 300
        private const val overlaySyncIntervalMs = 250L
        private const val panelOpenDurationMs = 180L
        private const val panelCloseDurationMs = 140L
        private const val bubbleOpenDurationMs = 120L
        private const val bubbleCloseDurationMs = 100L
        private const val bubbleIdleDelayMs = 2200L
        private const val bubbleDimDurationMs = 240L
        private const val idleBubbleAlpha = 0.82f
        private const val panelScaleStart = 0.98f
        private const val bubbleScaleStart = 0.96f
    }
}
