package app.deepos.runtime

import android.content.Context
import android.os.Build
import android.util.Log
import app.deepos.BuildConfig
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ServerSocket
import java.net.Socket
import java.net.URL
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Directory layout, 127.0.0.2 loopback detection, gateway asset staging,
 * and sdk28/sdk36 execution environment for the No-PRoot Claude Code runtime.
 *
 * All Termux devkit binaries are byte-rewritten for the 10-char package id
 * `app.deepos` (/data/data/com.termux/ -> /data/data/app.deepos/).
 */
class Env(context: Context) {
    companion object {
        const val TAG = "DeepOS"
        const val PORT = 8791

        @Volatile
        var uiHost: String = detectLoopbackHost()
            private set

        @Volatile
        var spawnSecret: String = ""

        @Volatile
        var verifiedBootId: String = ""

        private fun detectLoopbackHost(): String {
            var ok = false
            val t = Thread({
                try {
                    ServerSocket().use { ss ->
                        ss.reuseAddress = false
                        ss.bind(InetSocketAddress("127.0.0.2", 0))
                        Socket(Proxy.NO_PROXY).use { s ->
                            s.connect(InetSocketAddress("127.0.0.2", ss.localPort), 300)
                            ok = true
                        }
                    }
                } catch (_: Exception) {
                    ok = false
                }
            }, "deepos-loopback-probe")
            t.isDaemon = true
            t.start()
            try {
                t.join(450)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            return if (ok) "127.0.0.2" else "127.0.0.1"
        }

        fun randomHex(bytes: Int): String {
            val buf = ByteArray(bytes)
            SecureRandom().nextBytes(buf)
            return buf.joinToString("") { "%02x".format(it) }
        }

        fun hmacSha256Hex(key: String, data: String): String {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(key.toByteArray(Charsets.UTF_8), "HmacSHA256"))
            return mac.doFinal(data.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
        }
    }

    val appContext: Context = context.applicationContext
    val filesDir: File = appContext.filesDir
    val usrDir: File = File(filesDir, "usr")
    val gwDir: File = File(filesDir, "gw")
    val appDir: File = File(filesDir, "app")
    val homeDir: File = File(filesDir, "home")
    val workspaceDir: File = File(homeDir, "workspace")
    val tmpDir: File = File(filesDir, "tmp")
    val nativeLibDir: File = File(appContext.applicationInfo.nativeLibraryDir)

    val tokenFile: File = File(homeDir, ".gateway-token")
    val devkitOkFile: File = File(filesDir, ".devkit-ok")
    val claudeBinary: File = File(homeDir, ".local/bin/claude")
    val gatewayLog: File = File(filesDir, "gateway.log")

    val useLoaderExec: Boolean
        get() = BuildConfig.LOADER_EXEC || BuildConfig.TARGET_SDK_LEVEL >= 29

    val isDevkitInstalled: Boolean
        get() = devkitOkFile.isFile && File(usrDir, "bin/node").exists()

    val isClaudeInstalled: Boolean
        get() = claudeBinary.isFile && claudeBinary.length() > 1024 * 1024

    fun ensureDirectories() {
        listOf(usrDir, gwDir, appDir, homeDir, workspaceDir, tmpDir).forEach { it.mkdirs() }
    }

    fun readGatewayToken(): String =
        try {
            tokenFile.readText(Charsets.UTF_8).trim()
        } catch (_: Exception) {
            ""
        }

    /** Copies bundled `assets/gateway` tree into `files/app/` idempotently. */
    fun stageGatewayAssets() {
        ensureDirectories()
        copyAssetTree("gateway", appDir)
        File(appDir, "bin").listFiles()?.forEach { it.setExecutable(true, false) }
        File(appDir, "pre").listFiles()?.forEach { it.setExecutable(true, false) }
        File(appDir, "scripts").listFiles()?.forEach { it.setExecutable(true, false) }
    }

    private fun copyAssetTree(assetPath: String, targetDir: File) {
        val am = appContext.assets
        val children = am.list(assetPath) ?: return
        if (children.isEmpty()) {
            targetDir.parentFile?.mkdirs()
            am.open(assetPath).use { input ->
                FileOutputStream(targetDir).use { out -> input.copyTo(out) }
            }
            return
        }
        targetDir.mkdirs()
        for (name in children) {
            copyAssetTree("$assetPath/$name", File(targetDir, name))
        }
    }

    /** Builds the Node gateway launch command and environment for sdk28 (direct) or sdk36 (loader). */
    fun buildGatewayProcessBuilder(safeMode: Boolean): ProcessBuilder {
        ensureDirectories()
        val nodeBin = File(gwDir, "node").takeIf { it.isFile } ?: File(usrDir, "bin/node")
        val serverScript = File(appDir, "server.mjs")

        val cmd = if (useLoaderExec) {
            listOf(
                "/system/bin/linker64",
                nodeBin.absolutePath,
                "--openssl-config=/dev/null",
                serverScript.absolutePath,
                PORT.toString(),
            )
        } else {
            listOf(
                nodeBin.absolutePath,
                "--openssl-config=/dev/null",
                serverScript.absolutePath,
                PORT.toString(),
            )
        }

        val pb = ProcessBuilder(cmd)
        pb.directory(homeDir)
        pb.redirectErrorStream(true)

        val env = pb.environment()
        env["HOME"] = homeDir.absolutePath
        env["TMPDIR"] = tmpDir.absolutePath
        env["PREFIX"] = usrDir.absolutePath
        env["PATH"] = listOf(
            File(appDir, "pre").absolutePath,
            File(appDir, "bin").absolutePath,
            File(usrDir, "bin").absolutePath,
            "/system/bin",
        ).joinToString(":")
        env["LD_LIBRARY_PATH"] = listOf(
            gwDir.absolutePath,
            File(usrDir, "lib").absolutePath,
        ).joinToString(":")

        env["CCAPP_HOME"] = homeDir.absolutePath
        env["CCAPP_RUNTIME"] = filesDir.absolutePath
        env["CCAPP_PREFIX"] = usrDir.absolutePath
        env["CCAPP_WORKSPACE"] = workspaceDir.absolutePath
        env["CCAPP_APP"] = appDir.absolutePath
        env["CCAPP_BIN"] = File(appDir, "bin").absolutePath
        env["CCAPP_PORT"] = PORT.toString()
        env["CCAPP_UI_HOST"] = uiHost
        env["CCAPP_LOG"] = gatewayLog.absolutePath
        env["CCAPP_TMP"] = tmpDir.absolutePath
        env["CCAPP_TARGET_SDK"] = BuildConfig.TARGET_SDK_LEVEL.toString()
        env["CCAPP_NATIVE_LIB"] = nativeLibDir.absolutePath
        env["CCAPP_PTYHOST"] = File(nativeLibDir, "libccptyhost.so").absolutePath
        env["CCAPP_ENOSYS"] = File(nativeLibDir, "libccenosys.so").absolutePath
        env["CCAPP_ENOSYS_RUN"] = File(nativeLibDir, "libccenosysrun.so").absolutePath
        env["CCAPP_NODUMP"] = File(nativeLibDir, "libccnodump.so").absolutePath
        env["CCAPP_7ZZ"] = File(nativeLibDir, "libcc7zz.so").absolutePath
        env["CCAPP_LOADER"] = File(nativeLibDir, "libldlinux.so").absolutePath
        env["CCAPP_SPAWN_KEY"] = "stdin"
        env["CCAPP_EXEC"] = if (useLoaderExec) "loader" else "direct"
        if (useLoaderExec) {
            env["CCAPP_EXEC_SHIM"] = File(nativeLibDir, "libccexecshim.so").absolutePath
            env["CCAPP_EXEC_SHIM_BIONIC"] = File(nativeLibDir, "libccexecshimb.so").absolutePath
            env["CCAPP_LOADER_RUN"] = File(nativeLibDir, "libccrun.so").absolutePath
            val execPathHook = File(appDir, "execpath.cjs")
            if (execPathHook.isFile) {
                env["NODE_OPTIONS"] = "--require=${execPathHook.absolutePath}"
            }
        }
        if (safeMode) {
            env["CCAPP_SAFE_MODE"] = "1"
        }
        env["ANDROID_DATA"] = "/data"
        env["ANDROID_ROOT"] = "/system"
        env["LANG"] = "C.UTF-8"
        return pb
    }

    /** Verifies `GET /__proof?n=<nonce>` against the live loopback gateway. */
    fun proveGateway(): String? {
        val tok = readGatewayToken()
        val sp = spawnSecret
        if (tok.isEmpty() || sp.isEmpty()) return null
        val nonce = randomHex(16)
        return try {
            val conn = (URL("http://$uiHost:$PORT/__proof?n=$nonce")
                .openConnection(Proxy.NO_PROXY) as HttpURLConnection).apply {
                connectTimeout = 2000
                readTimeout = 2000
                instanceFollowRedirects = false
                setRequestProperty("Host", "$uiHost:$PORT")
            }
            if (conn.responseCode != 200) return null
            val text = conn.inputStream.bufferedReader(Charsets.UTF_8).readText().trim()
            conn.disconnect()
            val parts = text.split(" ")
            if (parts.size != 2) return null
            val boot = parts[0]
            val gotMac = parts[1]
            val derivedKey = hmacSha256Hex(tok, "spawn:$sp")
            val expected = hmacSha256Hex(derivedKey, "proof:$nonce:$boot:$uiHost")
            if (gotMac.equals(expected, ignoreCase = true)) {
                verifiedBootId = boot
                boot
            } else {
                Log.w(TAG, "Gateway /__proof HMAC mismatch on $uiHost:$PORT")
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    fun statusMap(phase: String, error: String? = null, progress: Double? = null, detail: String? = null): Map<String, Any?> {
        return mapOf(
            "phase" to phase,
            "packageId" to appContext.packageName,
            "targetSdk" to BuildConfig.TARGET_SDK_LEVEL,
            "deviceSdk" to Build.VERSION.SDK_INT,
            "execMode" to if (useLoaderExec) "loader" else "direct",
            "devkitInstalled" to isDevkitInstalled,
            "claudeInstalled" to isClaudeInstalled,
            "uiHost" to uiHost,
            "port" to PORT,
            "bootId" to verifiedBootId.ifEmpty { null },
            "token" to readGatewayToken().ifEmpty { null },
            "spawnSecret" to spawnSecret.ifEmpty { null },
            "homeDir" to homeDir.absolutePath,
            "workspaceDir" to workspaceDir.absolutePath,
            "error" to error,
            "progress" to progress,
            "detail" to detail,
        )
    }
}
