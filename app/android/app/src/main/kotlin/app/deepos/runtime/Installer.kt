package app.deepos.runtime

import android.util.Log
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.zip.GZIPInputStream

/**
 * First-launch & on-demand installer for:
 *   1. Modular Termux devkit packages rewritten for `app.deepos` (resumable + SHA-256 verified)
 *   2. Unmodified official Anthropic linux-arm64 Claude Code binary (downloaded from official
 *      distribution channel and verified against checksums — never bundled inside the APK).
 */
class Installer(
    private val env: Env,
    private val onProgress: (stage: String, detail: String, progress: Double) -> Unit,
) {
    companion object {
        private const val TAG = "DeepOS.Installer"
        private const val CLAUDE_RELEASE_BASE =
            "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
    }

    /**
     * Installs devkit from a local `.tar.gz` archive or downloads the pinned release
     * from `assets/devkit-sources.txt` (with Range resume + SHA-256 verification).
     */
    fun installDevkit(localArchivePath: String? = null, selectedModules: List<String> = listOf("base", "cli")) {
        env.ensureDirectories()
        env.stageGatewayAssets()

        if (localArchivePath != null && localArchivePath.isNotBlank()) {
            val localFile = File(localArchivePath)
            if (!localFile.isFile) throw IOException("Local devkit archive not found: $localArchivePath")
            onProgress("installing_devkit", "Extracting local devkit archive…", 0.35)
            extractTarGzRewritingPrefix(localFile, env.filesDir)
            env.devkitOkFile.writeText("local:${localFile.name}\n", Charsets.UTF_8)
            onProgress("installing_devkit", "Devkit ready", 1.0)
            return
        }

        val pinText = env.appContext.assets.open("devkit-pin.json").bufferedReader(Charsets.UTF_8).readText()
        val pin = JSONObject(pinText)
        val baseUrl = pin.optString("base").trimEnd('/') + "/"
        val gzObj = pin.optJSONObject("gz")
            ?: throw IOException("Invalid devkit-pin.json: missing gz entry")
        val fileName = gzObj.getString("file")
        val expectedSha = gzObj.optString("sha256", "")
        val expectedBytes = gzObj.optLong("bytes", 0L)

        val partFile = File(env.tmpDir, "$fileName.part")
        val doneFile = File(env.tmpDir, fileName)
        onProgress(
            "installing_devkit",
            "Downloading toolkit (${selectedModules.joinToString(", ")})…",
            0.05,
        )
        downloadResumable(
            url = baseUrl + fileName,
            partFile = partFile,
            doneFile = doneFile,
            expectedBytes = expectedBytes,
            expectedSha256 = expectedSha.ifEmpty { null },
        ) { done, total ->
            val frac = if (total > 0) (done.toDouble() / total.toDouble()).coerceIn(0.0, 1.0) else 0.2
            onProgress(
                "installing_devkit",
                "Downloading toolkit ${(done / (1024 * 1024))} / ${(total / (1024 * 1024))} MB",
                frac * 0.7,
            )
        }

        onProgress("installing_devkit", "Extracting & aligning prefix for app.deepos…", 0.75)
        extractTarGzRewritingPrefix(doneFile, env.filesDir)
        doneFile.delete()
        env.devkitOkFile.writeText("${pin.optString("tag")}\n", Charsets.UTF_8)
        onProgress("installing_devkit", "Toolkit installed", 1.0)
    }

    /**
     * Downloads the official, unmodified Anthropic linux-arm64 Claude Code binary
     * and verifies its SHA-256 against the official manifest.
     */
    fun installClaudeCode(channel: String = "stable") {
        env.ensureDirectories()
        onProgress("installing_claude", "Fetching official Claude Code ($channel) version…", 0.05)

        val version = fetchText("$CLAUDE_RELEASE_BASE/$channel").trim()
        if (version.isEmpty() || version.length > 64) {
            throw IOException("Invalid Claude Code version string: $version")
        }

        val manifestRaw = fetchText("$CLAUDE_RELEASE_BASE/$version/manifest.json")
        val manifest = JSONObject(manifestRaw)
        val platforms = manifest.optJSONObject("platforms")
            ?: throw IOException("Claude Code manifest missing platforms")
        val arm64 = platforms.optJSONObject("linux-arm64")
            ?: throw IOException("Claude Code manifest missing linux-arm64 entry")
        val expectedSha = arm64.optString("checksum", "")
        val expectedSize = arm64.optLong("size", 0L)

        val binUrl = "$CLAUDE_RELEASE_BASE/$version/linux-arm64/claude"
        val partFile = File(env.tmpDir, "claude-$version.part")
        val target = env.claudeBinary
        target.parentFile?.mkdirs()

        onProgress("installing_claude", "Downloading official Claude Code $version…", 0.1)
        downloadResumable(
            url = binUrl,
            partFile = partFile,
            doneFile = target,
            expectedBytes = expectedSize,
            expectedSha256 = expectedSha.ifEmpty { null },
        ) { done, total ->
            val frac = if (total > 0) (done.toDouble() / total.toDouble()).coerceIn(0.0, 1.0) else 0.5
            onProgress(
                "installing_claude",
                "Downloading Claude Code $version (${(done / (1024 * 1024))} MB)",
                0.1 + frac * 0.85,
            )
        }
        target.setExecutable(true, false)
        onProgress("installing_claude", "Claude Code $version verified", 1.0)
    }

    private fun fetchText(url: String): String {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 15000
            instanceFollowRedirects = true
        }
        try {
            if (conn.responseCode !in 200..299) {
                throw IOException("HTTP ${conn.responseCode} fetching $url")
            }
            return conn.inputStream.bufferedReader(Charsets.UTF_8).readText()
        } finally {
            conn.disconnect()
        }
    }

    private fun downloadResumable(
        url: String,
        partFile: File,
        doneFile: File,
        expectedBytes: Long,
        expectedSha256: String?,
        onBytes: (Long, Long) -> Unit,
    ) {
        if (doneFile.isFile && (expectedBytes <= 0 || doneFile.length() == expectedBytes)) {
            if (expectedSha256 == null || sha256(doneFile).equals(expectedSha256, ignoreCase = true)) {
                return
            }
        }
        val existing = if (partFile.isFile) partFile.length() else 0L
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 20000
            readTimeout = 30000
            instanceFollowRedirects = true
            if (existing > 0) {
                setRequestProperty("Range", "bytes=$existing-")
            }
        }
        try {
            val code = conn.responseCode
            val resume = code == 206 && existing > 0
            if (code !in 200..299) throw IOException("HTTP $code downloading $url")
            val contentLen = conn.contentLengthLong
            val total = when {
                expectedBytes > 0 -> expectedBytes
                resume && contentLen > 0 -> existing + contentLen
                contentLen > 0 -> contentLen
                else -> 0L
            }
            var copied = if (resume) existing else 0L
            FileOutputStream(partFile, resume).use { out ->
                BufferedInputStream(conn.inputStream).use { input ->
                    val buf = ByteArray(64 * 1024)
                    var lastReport = 0L
                    while (true) {
                        val n = input.read(buf)
                        if (n <= 0) break
                        out.write(buf, 0, n)
                        copied += n
                        val now = System.currentTimeMillis()
                        if (now - lastReport > 250) {
                            onBytes(copied, total)
                            lastReport = now
                        }
                    }
                }
            }
            onBytes(copied, total)
        } finally {
            conn.disconnect()
        }

        if (expectedSha256 != null) {
            val got = sha256(partFile)
            if (!got.equals(expectedSha256, ignoreCase = true)) {
                partFile.delete()
                throw IOException("SHA-256 mismatch for ${doneFile.name}: expected $expectedSha256, got $got")
            }
        }
        if (doneFile.exists()) doneFile.delete()
        if (!partFile.renameTo(doneFile)) {
            partFile.copyTo(doneFile, overwrite = true)
            partFile.delete()
        }
    }

    /**
     * Streams a `.tar.gz` devkit archive into [destRoot], performing exact 10-byte
     * equal-length prefix alignment (`/data/data/cc.codroid/` or `/data/data/com.termux/`
     * -> `/data/data/app.deepos/`) so upstream devkit releases work natively out of the box.
     */
    private fun extractTarGzRewritingPrefix(tarGz: File, destRoot: File) {
        val fromCodroid = "/data/data/cc.codroid/".toByteArray(Charsets.US_ASCII)
        val fromTermux = "/data/data/com.termux/".toByteArray(Charsets.US_ASCII)
        val toDeepos = "/data/data/app.deepos/".toByteArray(Charsets.US_ASCII)

        GZIPInputStream(BufferedInputStream(FileInputStream(tarGz), 64 * 1024)).use { gis ->
            val header = ByteArray(512)
            while (true) {
                val read = readFully(gis, header)
                if (read < 512 || header.all { it == 0.toByte() }) break
                val rawName = readTarString(header, 0, 100)
                val mode = readTarOctal(header, 100, 8).toInt()
                val size = readTarOctal(header, 124, 12)
                val typeFlag = header[156].toInt().toChar()
                val linkName = readTarString(header, 157, 100)
                val prefix = readTarString(header, 345, 155)
                val fullName = if (prefix.isNotEmpty()) "$prefix/$rawName" else rawName
                val cleanRel = fullName.removePrefix("./").removePrefix("/")
                if (cleanRel.isEmpty() || cleanRel.contains("..")) {
                    skipTarData(gis, size)
                    continue
                }
                val outFile = File(destRoot, cleanRel)
                when (typeFlag) {
                    '5' -> {
                        outFile.mkdirs()
                        skipTarData(gis, size)
                    }
                    '2' -> {
                        outFile.parentFile?.mkdirs()
                        outFile.delete()
                        val rewrittenLink = linkName
                            .replace("/data/data/cc.codroid/", "/data/data/app.deepos/")
                            .replace("/data/data/com.termux/", "/data/data/app.deepos/")
                        try {
                            android.system.Os.symlink(rewrittenLink, outFile.absolutePath)
                        } catch (e: Exception) {
                            Log.w(TAG, "symlink failed for $cleanRel -> $rewrittenLink: ${e.message}")
                        }
                        skipTarData(gis, size)
                    }
                    '0', '\u0000' -> {
                        outFile.parentFile?.mkdirs()
                        val data = ByteArray(size.toInt())
                        if (size > 0) readFully(gis, data)
                        rewriteInPlace(data, fromCodroid, toDeepos)
                        rewriteInPlace(data, fromTermux, toDeepos)
                        FileOutputStream(outFile).use { it.write(data) }
                        if ((mode and 0b001_001_001) != 0) {
                            outFile.setExecutable(true, false)
                        }
                        val pad = ((512 - (size % 512)) % 512).toInt()
                        if (pad > 0) skipFully(gis, pad.toLong())
                    }
                    else -> skipTarData(gis, size)
                }
            }
        }
    }

    private fun rewriteInPlace(buf: ByteArray, from: ByteArray, to: ByteArray) {
        if (buf.size < from.size) return
        var i = 0
        val limit = buf.size - from.size
        while (i <= limit) {
            var match = true
            for (j in from.indices) {
                if (buf[i + j] != from[j]) {
                    match = false
                    break
                }
            }
            if (match) {
                System.arraycopy(to, 0, buf, i, to.size)
                i += from.size
            } else {
                i++
            }
        }
    }

    private fun sha256(file: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { fis ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = fis.read(buf)
                if (n <= 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    private fun readFully(input: java.io.InputStream, buf: ByteArray): Int {
        var off = 0
        while (off < buf.size) {
            val n = input.read(buf, off, buf.size - off)
            if (n <= 0) break
            off += n
        }
        return off
    }

    private fun skipFully(input: java.io.InputStream, bytes: Long) {
        var rem = bytes
        val trash = ByteArray(4096)
        while (rem > 0) {
            val n = input.read(trash, 0, minOf(trash.size.toLong(), rem).toInt())
            if (n <= 0) break
            rem -= n
        }
    }

    private fun skipTarData(input: java.io.InputStream, size: Long) {
        if (size <= 0) return
        val total = ((size + 511) / 512) * 512
        skipFully(input, total)
    }

    private fun readTarString(header: ByteArray, offset: Int, len: Int): String {
        var end = offset
        while (end < offset + len && header[end] != 0.toByte()) end++
        return String(header, offset, end - offset, Charsets.UTF_8)
    }

    private fun readTarOctal(header: ByteArray, offset: Int, len: Int): Long {
        val s = readTarString(header, offset, len).trim()
        return if (s.isEmpty()) 0L else s.toLongOrNull(8) ?: 0L
    }
}
