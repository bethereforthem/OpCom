package com.opcom.opcom_mobile

import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var recorder: MediaRecorder? = null
    private var recFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.opcom.opcom_mobile/recorder"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start"  -> startRec(result)
                "stop"   -> stopRec(result)
                "cancel" -> cancelRec(result)
                else     -> result.notImplemented()
            }
        }
    }

    private fun startRec(result: MethodChannel.Result) {
        try {
            val f = File(cacheDir, "vn_${System.currentTimeMillis()}.m4a")
            recFile = f
            recorder = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION") MediaRecorder()
            }).apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16000)
                setAudioEncodingBitRate(32000)
                setOutputFile(f.absolutePath)
                prepare()
                start()
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("REC_ERR", e.message, null)
        }
    }

    private fun stopRec(result: MethodChannel.Result) {
        try {
            recorder?.stop()
            recorder?.release()
            recorder = null
            val f = recFile
            recFile = null
            if (f != null && f.exists()) {
                result.success(f.readBytes())
                f.delete()
            } else {
                result.error("NO_FILE", "Recording not found", null)
            }
        } catch (e: Exception) {
            recorder = null
            result.error("STOP_ERR", e.message, null)
        }
    }

    private fun cancelRec(result: MethodChannel.Result) {
        try { recorder?.stop() } catch (_: Exception) {}
        recorder?.release()
        recorder = null
        recFile?.delete()
        recFile = null
        result.success(null)
    }
}
