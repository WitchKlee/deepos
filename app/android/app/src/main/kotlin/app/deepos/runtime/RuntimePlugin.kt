package app.deepos.runtime

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Flutter platform bridge (`deepos/runtime` + `deepos/runtime/events`) exposing
 * modular devkit installation, official Claude Code verification, and GatewayService control.
 */
class RuntimePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var appContext: Context
    private lateinit var env: Env
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    private val gatewayStateListener: (String, String?) -> Unit = { phase, error ->
        emitStatus(phase = phase, error = error)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        env = Env(appContext)
        methodChannel = MethodChannel(binding.binaryMessenger, "deepos/runtime").also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, "deepos/runtime/events").also {
            it.setStreamHandler(this)
        }
        GatewayService.addStateListener(gatewayStateListener)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        GatewayService.removeStateListener(gatewayStateListener)
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        eventSink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        emitStatus(phase = computePhase(), error = GatewayService.lastError)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(env.statusMap(computePhase(), GatewayService.lastError))
            "startGateway" -> {
                val safeMode = call.argument<Boolean>("safeMode") ?: false
                GatewayService.start(appContext, safeMode = safeMode)
                result.success(true)
            }
            "stopGateway" -> {
                GatewayService.stop(appContext)
                result.success(true)
            }
            "installDevkit" -> {
                val localPath = call.argument<String>("localPath")
                val modules = call.argument<List<String>>("modules") ?: listOf("base", "cli")
                worker.execute {
                    try {
                        val installer = Installer(env) { stage, detail, progress ->
                            emitStatus(phase = stage, detail = detail, progress = progress)
                        }
                        installer.installDevkit(localArchivePath = localPath, selectedModules = modules)
                        emitStatus(phase = computePhase(), detail = "Toolkit installed", progress = 1.0)
                        mainHandler.post { result.success(env.statusMap(computePhase())) }
                    } catch (e: Exception) {
                        emitStatus(phase = "error", error = e.message ?: "Devkit install failed")
                        mainHandler.post { result.error("INSTALL_DEVKIT_FAILED", e.message, null) }
                    }
                }
            }
            "installClaude" -> {
                val channel = call.argument<String>("channel") ?: "stable"
                worker.execute {
                    try {
                        val installer = Installer(env) { stage, detail, progress ->
                            emitStatus(phase = stage, detail = detail, progress = progress)
                        }
                        installer.installClaudeCode(channel = channel)
                        emitStatus(phase = computePhase(), detail = "Claude Code verified", progress = 1.0)
                        mainHandler.post { result.success(env.statusMap(computePhase())) }
                    } catch (e: Exception) {
                        emitStatus(phase = "error", error = e.message ?: "Claude Code install failed")
                        mainHandler.post { result.error("INSTALL_CLAUDE_FAILED", e.message, null) }
                    }
                }
            }
            "readGatewayLog" -> {
                val tail = try {
                    if (env.gatewayLog.isFile) env.gatewayLog.readLines().takeLast(200).joinToString("\n") else ""
                } catch (_: Exception) {
                    ""
                }
                result.success(tail)
            }
            else -> result.notImplemented()
        }
    }

    private fun computePhase(): String {
        val svc = GatewayService.currentPhase
        if (svc == "running" || svc == "starting") return svc
        if (!env.isDevkitInstalled) return "not_installed"
        if (!env.isClaudeInstalled) return "need_claude"
        return "installed"
    }

    private fun emitStatus(
        phase: String,
        error: String? = null,
        progress: Double? = null,
        detail: String? = null,
    ) {
        val payload = env.statusMap(phase = phase, error = error, progress = progress, detail = detail)
        mainHandler.post {
            eventSink?.success(payload)
        }
    }
}
