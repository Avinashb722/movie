package com.example.flixo_app

import android.content.Context
import android.util.Log
import org.libtorrent4j.*
import org.libtorrent4j.alerts.*
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicBoolean

object TorrentEngine {
    private const val TAG = "TorrentEngine"

    // Session — created once and kept alive for the app lifetime
    private var sessionManager: SessionManager? = null

    // All @Volatile for thread-safety across Flutter's MethodChannel thread
    @Volatile private var activeInfoHash: Sha1Hash? = null
    @Volatile var metadataReceived: Boolean = false
    @Volatile private var isStopped: Boolean = true

    private val isInitialized = AtomicBoolean(false)

    // Video file info exposed to Flutter via getStatus()
    var largestVideoFileName: String? = null
    var largestVideoFilePath: String? = null
    var largestVideoFileSize: Long = 0L
    var selectedVideoIsMP4: Boolean = false   // Flutter uses this to pick threshold
    var saveDir: File? = null
    @Volatile private var activeSaveDir: File? = null
    @Volatile var videoFirstPiece: Int = -1
    @Volatile var videoLastPiece: Int = -1

    // -------------------------------------------------------------------------
    //  Video format priority — lower score = better
    //  Avoids 10-bit HEVC MKV when better options exist
    // -------------------------------------------------------------------------
    private fun videoFormatScore(path: String): Int {
        val lower = path.lowercase()
        val ext = lower.substringAfterLast('.', "")
        return when (ext) {
            "mp4"  -> 10
            "m4v"  -> 20
            "webm" -> 30
            "mkv"  -> {
                // Penalise 10-bit HEVC heavily — it's the most problematic for ExoPlayer
                if (lower.contains("10bit") || lower.contains("x265") || lower.contains("hevc")) 80
                else 40
            }
            "avi"  -> 50
            "mov"  -> 60
            "ts"   -> 70
            else   -> 100
        }
    }

    // -------------------------------------------------------------------------
    //  init() — call once from MainActivity
    // -------------------------------------------------------------------------
    fun init(context: Context) {
        if (isInitialized.getAndSet(true)) return

        Log.d(TAG, "Initializing TorrentEngine")
        saveDir = context.cacheDir

        sessionManager = SessionManager()

        // Configure optimized session settings
        val pack = SettingsPack()
        pack.connectionsLimit(200)
        
        // Enable DHT, LSD, Peer Exchange (PEX), and UPnP/NAT-PMP
        pack.setBoolean(org.libtorrent4j.swig.settings_pack.bool_types.enable_dht.swigValue(), true)
        pack.setBoolean(org.libtorrent4j.swig.settings_pack.bool_types.enable_lsd.swigValue(), true)
        pack.setBoolean(org.libtorrent4j.swig.settings_pack.bool_types.enable_upnp.swigValue(), true)
        pack.setBoolean(org.libtorrent4j.swig.settings_pack.bool_types.enable_natpmp.swigValue(), true)
        
        // Remove download & upload rate limits (0 = unlimited)
        pack.downloadRateLimit(0)
        pack.uploadRateLimit(0)

        sessionManager?.addListener(object : AlertListener {
            override fun types(): IntArray = intArrayOf(
                AlertType.ADD_TORRENT.swig(),
                AlertType.METADATA_RECEIVED.swig(),
                AlertType.PIECE_FINISHED.swig(),
                AlertType.TORRENT_FINISHED.swig(),
                AlertType.TORRENT_ERROR.swig()
            )

            override fun alert(alert: Alert<*>) {
                if (isStopped) return

                when (alert.type()) {

                    AlertType.ADD_TORRENT -> {
                        try {
                            val addAlert = alert as AddTorrentAlert
                            Log.d(TAG, "Torrent added — waiting for metadata")
                            val handle = addAlert.handle()
                            activeInfoHash = handle.infoHash()
                            try { handle.resume() } catch (e: Exception) {
                                Log.e(TAG, "Resume after add failed: ", e)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "ADD_TORRENT alert error: ", e)
                        }
                    }

                    AlertType.METADATA_RECEIVED -> {
                        try {
                            if (isStopped) return
                            val metaAlert = alert as MetadataReceivedAlert
                            Log.d(TAG, "Metadata received")
                            val handle = metaAlert.handle()
                            activeInfoHash = handle.infoHash()

                            try { handle.resume() } catch (e: Exception) {
                                Log.e(TAG, "Resume after metadata failed: ", e)
                            }

                            val info = try { handle.torrentFile() } catch (e: Exception) {
                                Log.e(TAG, "torrentFile() failed: ", e)
                                null
                            }

                            if (info != null) {
                                selectBestVideoAndPrioritize(handle, info)
                            }

                            // Allow Flutter to start polling
                            metadataReceived = true

                        } catch (e: Exception) {
                            Log.e(TAG, "METADATA_RECEIVED alert error: ", e)
                        }
                    }

                    AlertType.PIECE_FINISHED -> { /* no-op — we log progress via getStatus */ }

                    AlertType.TORRENT_FINISHED -> Log.d(TAG, "Torrent finished")

                    AlertType.TORRENT_ERROR -> Log.e(TAG, "Torrent error: $alert")

                    else -> {}
                }
            }
        })

        sessionManager?.start(SessionParams(pack))
        Log.d(TAG, "SessionManager started with optimized settings")
    }

    // -------------------------------------------------------------------------
    //  selectBestVideoAndPrioritize()
    //  • Picks best video by format score (MP4 > M4V > WebM > MKV)
    //  • Ignores all other files
    //  • Enables SEQUENTIAL_DOWNLOAD
    //  • Sets first 10% of pieces to SEVEN (highest priority)
    // -------------------------------------------------------------------------
    private fun selectBestVideoAndPrioritize(handle: TorrentHandle, info: TorrentInfo) {
        val fs = info.files()
        val videoExts = setOf("mp4", "mkv", "avi", "webm", "mov", "ts", "m4v")

        data class Candidate(val index: Int, val path: String, val size: Long, val score: Int)

        val candidates = mutableListOf<Candidate>()
        for (i in 0 until fs.numFiles()) {
            val path = fs.filePath(i)
            val ext = path.substringAfterLast('.', "").lowercase()
            if (ext in videoExts) {
                val size = fs.fileSize(i)
                if (size > 10 * 1024 * 1024) { // at least 10 MB
                    candidates.add(Candidate(i, path, size, videoFormatScore(path)))
                }
            }
        }

        if (candidates.isEmpty()) {
            Log.d(TAG, "No video files found in torrent")
            return
        }

        // Sort by (score ASC, size DESC) — prefer better format; break ties by larger file
        val best = candidates.sortedWith(compareBy<Candidate> { it.score }.thenByDescending { it.size }).first()

        Log.d(TAG, "Selected video [score=${best.score}]: ${best.path} (${best.size} bytes)")

        // Step 1: Prioritize files — IGNORE all except chosen video
        try {
            val priorities = Array(fs.numFiles()) { Priority.IGNORE }
            priorities[best.index] = Priority.SIX   // high (not max, leaves room for piece boosts)
            handle.prioritizeFiles(priorities)
            Log.d(TAG, "File priorities set: only index ${best.index} is active")
        } catch (e: Exception) {
            Log.e(TAG, "prioritizeFiles failed: ", e)
        }

        // Sequential download will be enabled dynamically in checkFileReady once the header/footer pieces are downloaded.

        // Step 3: Boost pieces of the selected video file
        try {
            val numPieces = info.numPieces()
            if (numPieces > 0) {
                val piecePriorities = Array<Priority>(numPieces) { Priority.IGNORE }
                
                val fileOffset = fs.fileOffset(best.index)
                val fileSize = fs.fileSize(best.index)
                val pieceLength = info.pieceLength().toLong()
                
                val firstPiece = (fileOffset / pieceLength).toInt()
                val lastPiece = ((fileOffset + fileSize - 1) / pieceLength).toInt()
                videoFirstPiece = firstPiece
                videoLastPiece = lastPiece
                
                val videoPieceCount = lastPiece - firstPiece + 1
                
                // Boost count for the beginning of the video (10%)
                val boostStartCount = maxOf(1, (videoPieceCount * 0.10).toInt())
                
                // Boost count for the end of the video (MKV files have metadata/Cues at the end)
                // Boost the last 3 pieces or 2% of the video pieces, whichever is larger
                val isMP4Like = best.path.lowercase().let {
                    it.endsWith(".mp4") || it.endsWith(".m4v") || it.endsWith(".webm")
                }
                val boostEndCount = if (!isMP4Like) {
                    maxOf(3, (videoPieceCount * 0.02).toInt())
                } else {
                    0
                }
                
                for (p in 0 until numPieces) {
                    if (p in firstPiece..lastPiece) {
                        val relativeIndex = p - firstPiece
                        if (relativeIndex < boostStartCount) {
                            piecePriorities[p] = Priority.TOP_PRIORITY
                        } else if (!isMP4Like && (lastPiece - p) < boostEndCount) {
                            piecePriorities[p] = Priority.TOP_PRIORITY
                        } else {
                            piecePriorities[p] = Priority.SIX
                        }
                    } else {
                        piecePriorities[p] = Priority.IGNORE
                    }
                }
                
                handle.prioritizePieces(piecePriorities)
                Log.d(TAG, "Piece priorities set: video file from piece $firstPiece to $lastPiece. Boosted first $boostStartCount pieces and last $boostEndCount pieces to TOP_PRIORITY.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "prioritizePieces failed: ", e)
        }

        // Persist metadata for Flutter
        largestVideoFileName = fs.fileName(best.index)
        largestVideoFilePath = File(activeSaveDir ?: saveDir, best.path).absolutePath
        largestVideoFileSize = best.size
        selectedVideoIsMP4 = best.path.lowercase().let {
            it.endsWith(".mp4") || it.endsWith(".m4v") || it.endsWith(".webm")
        }
        Log.d(TAG, "Video path: $largestVideoFilePath | isMP4-like: $selectedVideoIsMP4")
    }

    // -------------------------------------------------------------------------
    //  startTorrent()
    // -------------------------------------------------------------------------
    fun startTorrent(magnetUri: String, customSaveDir: File? = null) {
        Log.d(TAG, "============================================")
        Log.d(TAG, "startTorrent() called")
        Log.d(TAG, "Magnet URI: $magnetUri")
        Log.d(TAG, "============================================")

        isStopped = false
        metadataReceived = false
        largestVideoFileName = null
        largestVideoFilePath = null
        largestVideoFileSize = 0L
        selectedVideoIsMP4 = false
        videoFirstPiece = -1
        videoLastPiece = -1

        stopTorrent(resetStarted = false)  // remove any previous torrent silently

        var dir = customSaveDir ?: saveDir ?: return
        if (dir.absolutePath.contains("app_flutter") || dir.absolutePath.contains("files")) {
            val publicDir = File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS), "Flixo")
            if (!publicDir.exists()) {
                publicDir.mkdirs()
            }
            if (publicDir.exists()) {
                dir = publicDir
            }
        }
        activeSaveDir = dir
        Log.d(TAG, "Save dir: ${dir.absolutePath}")

        try {
            sessionManager?.download(magnetUri, dir, TorrentFlags.AUTO_MANAGED)
        } catch (e: Exception) {
            Log.e(TAG, "download() failed: ", e)
            isStopped = true
        }
    }

    // -------------------------------------------------------------------------
    //  stopTorrent()
    // -------------------------------------------------------------------------
    @JvmOverloads
    fun stopTorrent(resetStarted: Boolean = true) {
        Log.d(TAG, "stopTorrent() called (resetStarted=$resetStarted)")
        if (resetStarted) {
            isStopped = true
            metadataReceived = false
            activeSaveDir = null
        }

        val hash = activeInfoHash
        activeInfoHash = null

        if (hash != null) {
            try {
                val handle = sessionManager?.find(hash)
                if (handle != null) {
                    sessionManager?.remove(handle)
                }
            } catch (e: Exception) {
                Log.e(TAG, "remove() failed: ", e)
            }
        }

        if (resetStarted) {
            largestVideoFileName = null
            largestVideoFilePath = null
            largestVideoFileSize = 0L
            selectedVideoIsMP4 = false
            videoFirstPiece = -1
            videoLastPiece = -1
        }
    }

    // -------------------------------------------------------------------------
    //  getStatus() — the only method Flutter polls; NEVER crashes
    // -------------------------------------------------------------------------
    fun getStatus(): Map<String, Any?> {
        if (isStopped) {
            return idleStatus("idle")
        }
        if (!metadataReceived) {
            return idleStatus("metadata_pending")
        }

        val hash = activeInfoHash ?: return idleStatus("idle")

        val handle = sessionManager?.find(hash) ?: run {
            Log.w(TAG, "getStatus() → hash ${hash.toHex()} not found in session")
            return idleStatus("idle")
        }

        return try {
            val status = handle.status()
            mapOf(
                "isValid"          to true,
                "name"             to tryGet { status.name() },
                "progress"         to tryGet { status.progress().toDouble() },
                "downloadSpeed"    to tryGet { status.downloadRate().toDouble() },
                "uploadSpeed"      to tryGet { status.uploadRate().toDouble() },
                "peers"            to tryGet { status.numPeers() },
                "totalWanted"      to tryGet { status.totalWanted() },
                "totalDone"        to tryGet { status.totalDone() },
                "state"            to tryGet { status.state().name },
                "filePath"         to largestVideoFilePath,
                "fileName"         to largestVideoFileName,
                "videoFileSize"    to largestVideoFileSize,
                "selectedVideoIsMP4" to selectedVideoIsMP4
            )
        } catch (e: Exception) {
            Log.e(TAG, "getStatus() native call failed (crash prevented): $e")
            idleStatus("error")
        }
    }

    // -------------------------------------------------------------------------
    //  checkFileReady() — called from MainActivity for format-specific header checks
    //  NOTE: raf.length() is NOT used because libtorrent pre-allocates the full
    //  file on disk — it always returns the complete file size regardless of how
    //  much data has actually been downloaded. Use totalDone from getStatus() instead.
    // -------------------------------------------------------------------------
    fun checkFileReady(filePath: String): String {
        val file = File(filePath)
        if (!file.exists()) return "NOT_READY"

        val hash = activeInfoHash ?: return "NOT_READY"
        val handle = sessionManager?.find(hash) ?: return "NOT_READY"



        val lower = filePath.lowercase()
        val isMkv  = lower.endsWith(".mkv")
        val isMP4  = lower.endsWith(".mp4") || lower.endsWith(".m4v")
        val isWebm = lower.endsWith(".webm")

        return try {
            RandomAccessFile(file, "r").use { raf ->
                // Scan the first 2 MB — enough to find headers for all common formats
                val scanLen = minOf(raf.length(), 2L * 1024 * 1024).toInt()
                if (scanLen < 16) {
                    Log.d(TAG, "checkFileReady: file too small ($scanLen bytes)")
                    return "NOT_READY"
                }
                val buf = ByteArray(scanLen)
                raf.seek(0)
                raf.readFully(buf)

                when {
                    isMP4 -> {
                        // MP4: look for 'ftyp' box (bytes: 66 74 79 70)
                        val ftyp = byteArrayOf(0x66, 0x74, 0x79, 0x70)
                        if (findBytes(buf, ftyp)) {
                            Log.d(TAG, "MP4 ftyp box found — READY")
                            try {
                                handle.setFlags(TorrentFlags.SEQUENTIAL_DOWNLOAD)
                                Log.d(TAG, "MP4 header ready — sequential download enabled for streaming!")
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to set sequential download: ", e)
                            }
                            "READY"
                        } else {
                            Log.d(TAG, "MP4 ftyp box not found yet in first ${scanLen / 1024} KB")
                            "NOT_READY"
                        }
                    }

                    isWebm -> {
                        // WebM shares EBML header with MKV
                        val ebml = byteArrayOf(0x1A.toByte(), 0x45.toByte(), 0xDF.toByte(), 0xA3.toByte())
                        if (findBytes(buf, ebml)) {
                            Log.d(TAG, "WebM EBML header found — READY")
                            try {
                                handle.setFlags(TorrentFlags.SEQUENTIAL_DOWNLOAD)
                                Log.d(TAG, "WebM header ready — sequential download enabled!")
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to set sequential download: ", e)
                            }
                            "READY"
                        } else {
                            Log.d(TAG, "WebM EBML header not found yet")
                            "NOT_READY"
                        }
                    }

                    isMkv -> {
                        // MKV: require BOTH the EBML header AND the Tracks element.
                        // ExoPlayer needs Tracks to resolve codecs — without it playback fails
                        // even when the EBML header is present.
                        val ebml   = byteArrayOf(0x1A.toByte(), 0x45.toByte(), 0xDF.toByte(), 0xA3.toByte())
                        val tracks = byteArrayOf(0x16.toByte(), 0x54.toByte(), 0xAE.toByte(), 0x6B.toByte())

                        val hasEbml   = findBytes(buf, ebml)
                        val hasTracks = findBytes(buf, tracks)

                        Log.d(TAG, "MKV check — EBML: $hasEbml  Tracks: $hasTracks  (scan=${scanLen/1024} KB)")

                        // Guard: For MKV, make sure the last pieces are downloaded
                        var lastPiecesDownloaded = true
                        if (videoLastPiece != -1) {
                            val checkEndCount = 3
                            for (p in (videoLastPiece - checkEndCount + 1)..videoLastPiece) {
                                if (p >= 0 && !handle.havePiece(p)) {
                                    lastPiecesDownloaded = false
                                    Log.d(TAG, "checkFileReady: MKV not ready because piece $p (near end of file) is not downloaded yet")
                                    break
                                }
                            }
                        }

                        if (hasEbml && hasTracks && lastPiecesDownloaded) {
                            try {
                                handle.setFlags(TorrentFlags.SEQUENTIAL_DOWNLOAD)
                                Log.d(TAG, "MKV headers/footers ready — sequential download enabled for streaming!")
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to set sequential download: ", e)
                            }
                            "READY"
                        } else {
                            "NOT_READY"
                        }
                    }

                    else -> {
                        // Unknown format — let Flutter's totalDone gate decide
                        "READY"
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "checkFileReady error for $filePath: ", e)
            "NOT_READY"
        }
    }

    private fun findBytes(haystack: ByteArray, needle: ByteArray): Boolean {
        if (needle.isEmpty() || haystack.size < needle.size) return false
        outer@ for (i in 0..haystack.size - needle.size) {
            for (j in needle.indices) {
                if (haystack[i + j] != needle[j]) continue@outer
            }
            return true
        }
        return false
    }

    // -------------------------------------------------------------------------
    //  Helpers
    // -------------------------------------------------------------------------

    private fun idleStatus(state: String): Map<String, Any?> = mapOf(
        "isValid"           to false,
        "name"              to "",
        "progress"          to 0.0,
        "downloadSpeed"     to 0.0,
        "uploadSpeed"       to 0.0,
        "peers"             to 0,
        "totalWanted"       to 0L,
        "totalDone"         to 0L,
        "state"             to state,
        "filePath"          to largestVideoFilePath,
        "fileName"          to largestVideoFileName,
        "videoFileSize"     to largestVideoFileSize,
        "selectedVideoIsMP4" to selectedVideoIsMP4
    )

    @Suppress("UNCHECKED_CAST")
    private fun <T> tryGet(default: T? = null, block: () -> T): T? {
        return try { block() } catch (e: Exception) { default }
    }
}
