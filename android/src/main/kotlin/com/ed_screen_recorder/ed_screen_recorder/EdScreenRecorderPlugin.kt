package com.ed_screen_recorder.ed_screen_recorder

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowInsets
import com.hbisoft.hbrecorder.HBRecorder
import com.hbisoft.hbrecorder.HBRecorderListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale


/** EdScreenRecorderPlugin  */
class EdScreenRecorderPlugin : FlutterPlugin, ActivityAware, MethodCallHandler,
    ActivityResultListener, HBRecorderListener {

    private val SCREEN_RECORD_REQUEST_CODE = 777
    private var flutterPluginBinding: FlutterPluginBinding? = null
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var recentResult: MethodChannel.Result? = null
    private var startRecordingResult: MethodChannel.Result? = null
    private var stopRecordingResult: MethodChannel.Result? = null
    private var pauseRecordingResult: MethodChannel.Result? = null
    private var resumeRecordingResult: MethodChannel.Result? = null
    private var activity: Activity? = null
    private var hbRecorder: HBRecorder? = null
    private var isAudioEnabled = false
    private var fileName: String? = null
    private var dirPathToSave: String? = null
    private var addTimeCode = false
    private var filePath: String? = null
    private var videoFrame = 0
    private var videoBitrate = 0
    private var fileOutputFormat: String? = null
    private var fileExtension: String? = null
    private var success = false
    private var videoHash: String? = null
    private var startDate: Long = 0
    private var endDate: Long = 0
    private var codec: String? = null
    private var scale: Double = 1.0
    private fun initializeResults() {
        startRecordingResult = null
        stopRecordingResult = null
        pauseRecordingResult = null
        resumeRecordingResult = null
        recentResult = null
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        flutterPluginBinding = binding
        hbRecorder = HBRecorder(flutterPluginBinding!!.applicationContext, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        flutterPluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityPluginBinding = binding
        setupChannels(flutterPluginBinding!!.binaryMessenger, binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {}
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        initializeResults()
        recentResult = result
        when (call.method) {
            "startRecordScreen" -> try {
                startRecordingResult = result
                isAudioEnabled = java.lang.Boolean.TRUE == call.argument("audioenable")
                fileName = call.argument("filename")
                dirPathToSave = call.argument("dirpathtosave")
                addTimeCode = java.lang.Boolean.TRUE == call.argument("addtimecode")
                videoFrame = call.argument("videoframe")!!
                videoBitrate = call.argument("videobitrate")!!
                fileOutputFormat = call.argument("fileoutputformat")
                fileExtension = call.argument("fileextension")
                videoHash = call.argument("videohash")
                startDate = call.argument("startdate")!!
                codec = call.argument("codec")
                scale = call.argument("scale") ?: 1.0
                customSettings(
                    videoFrame,
                    videoBitrate,
                    fileOutputFormat,
                    addTimeCode,
                    fileName,
                    codec,
                    scale
                )
                if (dirPathToSave != null) {
                    println(">>>>>>>>>>> 1")
                    setOutputPath(addTimeCode, fileName, dirPathToSave)
                }
                success = startRecordingScreen()
            } catch (e: Exception) {
                val dataMap: MutableMap<Any?, Any?> = HashMap()
                dataMap["success"] = false
                dataMap["isProgress"] = false
                dataMap["file"] = ""
                dataMap["eventname"] = "startRecordScreen Error"
                dataMap["message"] = e.message
                dataMap["videohash"] = videoHash
                dataMap["startdate"] = startDate
                dataMap["enddate"] = endDate
                val jsonObj = JSONObject(dataMap)
                startRecordingResult!!.success(jsonObj.toString())
                startRecordingResult = null
                recentResult = null
                println("Error: " + e.message)
            }

            "pauseRecordScreen" -> {
                pauseRecordingResult = result
                hbRecorder!!.pauseScreenRecording()
            }

            "resumeRecordScreen" -> {
                resumeRecordingResult = result
                hbRecorder!!.resumeScreenRecording()
            }

            "stopRecordScreen" -> {
                stopRecordingResult = result
                endDate = call.argument("enddate")!!
                hbRecorder!!.stopScreenRecording()
            }

            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                if (data != null) {
                    hbRecorder!!.startScreenRecording(data, resultCode)
                }
            }
        }
        return true
    }

    private fun setupChannels(messenger: BinaryMessenger, activity: Activity?) {
        if (activityPluginBinding != null) {
            activityPluginBinding!!.addActivityResultListener(this)
        }
        this.activity = activity
        val channel = MethodChannel(messenger, "ed_screen_recorder")
        channel.setMethodCallHandler(this)
    }

    override fun HBRecorderOnStart() {
        Log.e("Video Start:", "Start called")
        val dataMap: MutableMap<Any?, Any?> = HashMap()
        dataMap["success"] = success
        dataMap["isProgress"] = true
        if (dirPathToSave != null) {
            dataMap["file"] = "$filePath.$fileExtension"
        } else {
            dataMap["file"] = generateFileName(fileName, addTimeCode) + "." + fileExtension
        }
        dataMap["eventname"] = "startRecordScreen"
        dataMap["message"] = "Started Video"
        dataMap["videohash"] = videoHash
        dataMap["startdate"] = startDate
        dataMap["enddate"] = null
        val jsonObj = JSONObject(dataMap)
        if (startRecordingResult != null) {
            startRecordingResult!!.success(jsonObj.toString())
            startRecordingResult = null
            recentResult = null
        }
    }

    override fun HBRecorderOnComplete() {
        Log.e("Video Complete:", "Complete called")
        val dataMap: MutableMap<Any?, Any?> = HashMap()
        dataMap["success"] = success
        dataMap["isProgress"] = false
        if (dirPathToSave != null) {
            dataMap["file"] = "$filePath.$fileExtension"
        } else {
            dataMap["file"] = generateFileName(fileName, addTimeCode) + "." + fileExtension
        }
        dataMap["eventname"] = "stopRecordScreen"
        dataMap["message"] = "Paused Video"
        dataMap["videohash"] = videoHash
        dataMap["startdate"] = startDate
        dataMap["enddate"] = endDate
        val jsonObj = JSONObject(dataMap)
        try {
            if (stopRecordingResult != null) {
                stopRecordingResult!!.success(jsonObj.toString())
                stopRecordingResult = null
                recentResult = null
            }
        } catch (e: Exception) {
            println("Error:" + e.message)
            if (recentResult != null) {
                recentResult!!.error("Error", e.message, null)
                recentResult = null
            }
        }
    }

    override fun HBRecorderOnError(errorCode: Int, reason: String) {
        Log.e("Video Error:", reason)
        if (recentResult != null) {
            recentResult!!.error("Error", reason, null)
            recentResult = null
        }
    }

    override fun HBRecorderOnPause() {
        if (pauseRecordingResult != null) {
            pauseRecordingResult!!.success(true)
            pauseRecordingResult = null
            recentResult = null
        }
    }

    override fun HBRecorderOnResume() {
        if (resumeRecordingResult != null) {
            resumeRecordingResult!!.success(true)
            resumeRecordingResult = null
            recentResult = null
        }
    }

    private fun startRecordingScreen(): Boolean {
        return try {
            hbRecorder!!.enableCustomSettings()
            val mediaProjectionManager = flutterPluginBinding
                ?.applicationContext
                ?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val permissionIntent = mediaProjectionManager.createScreenCaptureIntent()
            activity!!.startActivityForResult(permissionIntent, SCREEN_RECORD_REQUEST_CODE)
            true
        } catch (e: Exception) {
            println("Error:" + e.message)
            false
        }
    }

    private fun customSettings(
        videoFrame: Int, videoBitrate: Int, fileOutputFormat: String?, addTimeCode: Boolean,
        fileName: String?, encoder: String?, scale: Double
    ) {
        val width: Int?
        val height: Int?
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = activity?.windowManager?.currentWindowMetrics
            width = metrics?.bounds?.width()
            height = metrics?.bounds?.height()
        } else {
            val view = activity?.window?.decorView
            width = view?.width
            height = view?.height
        }
        hbRecorder!!.isAudioEnabled(isAudioEnabled)
        hbRecorder!!.setAudioSource("DEFAULT")
        hbRecorder!!.setVideoEncoder(encoder)
        hbRecorder!!.setVideoFrameRate(videoFrame)
        hbRecorder!!.setVideoBitrate(videoBitrate)
        hbRecorder!!.setOutputFormat(fileOutputFormat)
        if (width != null && height != null) {
            hbRecorder!!.setScreenDimensions((height * scale).toInt(), (width * scale).toInt())
        }
        if (dirPathToSave == null) {
            println(">>>>>>>>>>> 2$fileName")
            hbRecorder!!.fileName = generateFileName(fileName, addTimeCode)
        }
    }

    @Throws(IOException::class)
    private fun setOutputPath(addTimeCode: Boolean, fileName: String?, dirPathToSave: String?) {
        hbRecorder!!.fileName = generateFileName(fileName, addTimeCode)
        filePath = if (dirPathToSave != null && dirPathToSave != "") {
            val dirFile = File(dirPathToSave)
            hbRecorder!!.setOutputPath(dirFile.absolutePath)
            dirFile.absolutePath + "/" + generateFileName(fileName, addTimeCode)
        } else {
            hbRecorder!!.setOutputPath(
                flutterPluginBinding!!.applicationContext.externalCacheDir!!.absolutePath
            )
            (flutterPluginBinding!!.applicationContext.externalCacheDir!!.absolutePath + "/"
                    + generateFileName(fileName, addTimeCode))
        }
    }

    private fun generateFileName(fileName: String?, addTimeCode: Boolean): String? {
        val formatter = SimpleDateFormat("yyyy-MM-dd-HH-mm-ss", Locale.getDefault())
        val curDate = Date(System.currentTimeMillis())
        return if (addTimeCode) {
            fileName + "-" + formatter.format(curDate).replace(" ", "")
        } else {
            fileName
        }
    }
}
