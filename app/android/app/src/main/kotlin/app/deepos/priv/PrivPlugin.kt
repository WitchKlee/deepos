package app.deepos.priv

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.File

/**
 * Optional CLI-only Shizuku helper (`deepos/priv`) for terminal `priv '<cmd>'`
 * and `cc-mem` memory management. Never registers or uses AccessibilityService.
 */
class PrivPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val SHIZUKU_PKG = "moe.shizuku.privileged.api"
        private const val REQ_CODE = 0x5072
    }

    private lateinit var appContext: Context
    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val permListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode == REQ_CODE) {
            mainHandler.post {
                channel?.invokeMethod(
                    "onPermissionResult",
                    mapOf("granted" to (grantResult == PackageManager.PERMISSION_GRANTED)),
                )
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "deepos/priv").also {
            it.setMethodCallHandler(this)
        }
        try {
            Shizuku.addRequestPermissionResultListener(permListener)
        } catch (_: Throwable) {
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            Shizuku.removeRequestPermissionResultListener(permListener)
        } catch (_: Throwable) {
        }
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(statusMap())
            "requestPermission" -> {
                try {
                    if (!Shizuku.pingBinder()) {
                        result.success(false)
                        return
                    }
                    if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                        return
                    }
                    Shizuku.requestPermission(REQ_CODE)
                    result.success(true)
                } catch (e: Throwable) {
                    result.error("SHIZUKU_ERROR", e.message, null)
                }
            }
            "openShizukuManager" -> {
                val launch = appContext.packageManager.getLaunchIntentForPackage(SHIZUKU_PKG)
                if (launch != null) {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    appContext.startActivity(launch)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "readAuditLog" -> {
                val auditFile = File(appContext.filesDir, "home/priv-audit.jsonl")
                val lines = try {
                    if (auditFile.isFile) auditFile.readLines(Charsets.UTF_8).takeLast(100) else emptyList()
                } catch (_: Exception) {
                    emptyList()
                }
                result.success(lines)
            }
            else -> result.notImplemented()
        }
    }

    private fun statusMap(): Map<String, Any?> {
        val installed = try {
            appContext.packageManager.getPackageInfo(SHIZUKU_PKG, 0)
            true
        } catch (_: Exception) {
            false
        }
        val alive = try {
            Shizuku.pingBinder()
        } catch (_: Throwable) {
            false
        }
        val granted = alive && try {
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Throwable) {
            false
        }
        val uid = if (alive) {
            try {
                Shizuku.getUid()
            } catch (_: Throwable) {
                null
            }
        } else {
            null
        }
        return mapOf(
            "installed" to installed,
            "running" to alive,
            "granted" to granted,
            "uid" to uid,
        )
    }
}
