package app.deepos

import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Main Flutter host activity for DeepOS (`app.deepos`).
 * Configures edge-to-edge transparent system bars and requests peak 120Hz display refresh rate.
 */
class MainActivity : FlutterActivity() {
    private var votedView: SurfaceView? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        DeepOsFlutterEngine.getOrCreate(context)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        @Suppress("DEPRECATION")
        window.statusBarColor = Color.TRANSPARENT
        @Suppress("DEPRECATION")
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
    }

    override fun onResume() {
        super.onResume()
        applyPeakRefreshRate()
    }

    /** Votes for the highest supported refresh rate on the current display resolution (90/120/144Hz). */
    private fun applyPeakRefreshRate() {
        @Suppress("DEPRECATION")
        val display = windowManager.defaultDisplay ?: return
        val current = display.mode
        val peak = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate }
            ?: return

        if (window.attributes.preferredDisplayModeId != peak.modeId) {
            window.attributes = window.attributes.apply { preferredDisplayModeId = peak.modeId }
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val view = findSurfaceView(findViewById(FLUTTER_VIEW_ID)) ?: return
        if (view !== votedView) {
            votedView = view
            view.holder.addCallback(object : SurfaceHolder.Callback {
                override fun surfaceCreated(holder: SurfaceHolder) = applyPeakRefreshRate()
                override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}
                override fun surfaceDestroyed(holder: SurfaceHolder) {}
            })
        }
        val surface = view.holder.surface
        if (surface.isValid) {
            surface.setFrameRate(peak.refreshRate, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
        }
    }

    private fun findSurfaceView(view: View?): SurfaceView? {
        if (view is SurfaceView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                findSurfaceView(view.getChildAt(i))?.let { return it }
            }
        }
        return null
    }
}
