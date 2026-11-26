package app.deepos.theme

import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Samples Android 12+ Material You system accent color for DeepOS theme palette. */
class DynamicColorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var appContext: Context
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "deepos/dynamic_color").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "accentColor") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val color = appContext.getColor(android.R.color.system_accent1_500)
                result.success(color)
            } else {
                result.success(null)
            }
        } else {
            result.notImplemented()
        }
    }
}
