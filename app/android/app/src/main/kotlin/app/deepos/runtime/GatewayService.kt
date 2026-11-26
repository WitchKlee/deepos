package app.deepos.runtime

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import app.deepos.MainActivity
import java.io.FileOutputStream

/**
 * Foreground service hosting the local Claude Code Node gateway (`gateway/server.mjs`).
 *
 * - Keeps the gateway alive under Android background restrictions with a partial WakeLock.
 * - Injects a per-boot random `SPAWN_KEY` via stdin pipe (never stored on disk or env).
 * - Supervises `/__proof` liveness and restarts cleanly on unexpected exit.
 */
class GatewayService : Service() {
    companion object {
        private const val TAG = "DeepOS.GatewayService"
        private const val CHANNEL_ID = "deepos_gateway"
        private const val NOTIFY_ID = 1001
        const val ACTION_START = "app.deepos.action.START_GATEWAY"
        const val ACTION_STOP = "app.deepos.action.STOP_GATEWAY"
        const val EXTRA_SAFE_MODE = "safe_mode"

        @Volatile
        private var instance: GatewayService? = null

        @Volatile
        var currentPhase: String = "stopped"
            private set

        @Volatile
        var lastError: String? = null
            private set

        private val listeners = java.util.concurrent.CopyOnWriteArraySet<(String, String?) -> Unit>()

        fun addStateListener(cb: (String, String?) -> Unit) {
            listeners.add(cb)
        }

        fun removeStateListener(cb: (String, String?) -> Unit) {
            listeners.remove(cb)
        }

        private fun publishState(phase: String, error: String? = null) {
            currentPhase = phase
            lastError = error
            for (cb in listeners) {
                try {
                    cb(phase, error)
                } catch (_: Exception) {
                }
            }
        }

        fun start(context: Context, safeMode: Boolean = false) {
            val intent = Intent(context, GatewayService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SAFE_MODE, safeMode)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, GatewayService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private lateinit var env: Env
    private var wakeLock: PowerManager.WakeLock? = null
    private val lifeLock = Any()
    private var lifeGen = 0L

    @Volatile
    private var proc: Process? = null

    @Volatile
    private var stopping = false
    private var supervisor: Thread? = null
    private var safeMode = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        env = Env(this)
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopping = true
            killGateway()
            publishState("stopped", null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        safeMode = intent?.getBooleanExtra(EXTRA_SAFE_MODE, false) ?: false
        stopping = false
        startForeground(NOTIFY_ID, buildNotification("Starting Claude Code gateway…"))
        acquireWakeLock()

        synchronized(lifeLock) {
            if (supervisor?.isAlive != true) {
                val gen = ++lifeGen
                supervisor = Thread({ superviseLoop(gen) }, "deepos-gw-supervisor").apply {
                    isDaemon = true
                    start()
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopping = true
        killGateway()
        releaseWakeLock()
        instance = null
        publishState("stopped", null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun superviseLoop(gen: Long) {
        var backoffMs = 800L
        while (!stopping) {
            synchronized(lifeLock) {
                if (gen != lifeGen) return
            }
            if (!env.isDevkitInstalled) {
                publishState("not_installed", "Toolkit is not installed yet")
                return
            }
            try {
                publishState("starting", null)
                env.stageGatewayAssets()
                val secret = Env.randomHex(32)
                Env.spawnSecret = secret
                Env.verifiedBootId = ""

                val pb = env.buildGatewayProcessBuilder(safeMode)
                val p = pb.start()
                proc = p

                // Inject SPAWN_KEY over stdin pipe and close stdin immediately.
                try {
                    p.outputStream.write("$secret\n".toByteArray(Charsets.US_ASCII))
                    p.outputStream.flush()
                    p.outputStream.close()
                } catch (e: Exception) {
                    Log.w(TAG, "Failed writing SPAWN_KEY to gateway stdin: ${e.message}")
                }

                // Pump stdout/stderr into gateway.log asynchronously.
                Thread({
                    try {
                        FileOutputStream(env.gatewayLog, true).use { fos ->
                            p.inputStream.copyTo(fos)
                        }
                    } catch (_: Exception) {
                    }
                }, "deepos-gw-log").apply {
                    isDaemon = true
                    start()
                }

                // Wait up to 20s for /__proof HMAC handshake.
                val deadline = System.currentTimeMillis() + 20_000L
                var boot: String? = null
                while (!stopping && p.isAlive && System.currentTimeMillis() < deadline) {
                    boot = env.proveGateway()
                    if (boot != null) break
                    Thread.sleep(250)
                }

                if (boot != null) {
                    backoffMs = 800L
                    updateNotification("Claude Code gateway running (${Env.uiHost}:${Env.PORT})")
                    publishState("running", null)
                    val code = p.waitFor()
                    Log.w(TAG, "Gateway exited with code $code")
                } else {
                    Log.e(TAG, "Gateway failed /__proof within 20s; restarting")
                    killGateway()
                    publishState("error", "Gateway failed identity handshake")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Gateway supervisor error", e)
                publishState("error", e.message ?: "Gateway error")
            }

            if (stopping) break
            try {
                Thread.sleep(backoffMs)
            } catch (_: InterruptedException) {
                break
            }
            backoffMs = (backoffMs * 2).coerceAtMost(10_000L)
        }
    }

    private fun killGateway() {
        synchronized(lifeLock) {
            lifeGen++
            val p = proc
            proc = null
            if (p != null) {
                try {
                    p.destroy()
                    if (!p.waitFor(1500, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                        p.destroyForcibly()
                    }
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DeepOS:GatewayWakeLock").apply {
            setReferenceCounted(false)
            acquire(6 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "DeepOS Claude Code Gateway",
                NotificationManager.IMPORTANCE_LOW,
            )
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(text: String): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("DeepOS")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .setContentIntent(openIntent)
            .build()
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFY_ID, buildNotification(text))
    }
}
