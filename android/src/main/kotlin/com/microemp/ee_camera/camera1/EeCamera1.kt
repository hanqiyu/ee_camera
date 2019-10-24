package com.microemp.ee_camera.camera1

import android.app.Activity
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.view.FlutterView
import android.hardware.Camera
import io.flutter.view.TextureRegistry
import android.view.Surface;
import android.media.MediaRecorder
import java.io.IOException
import java.util.ArrayList
import java.util.Collections
import java.util.Comparator
import kotlin.math.*

import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Matrix;
import android.graphics.Bitmap.createBitmap


import java.io.BufferedOutputStream;
import java.io.FileOutputStream;

import android.view.OrientationEventListener;
import android.view.OrientationEventListener.ORIENTATION_UNKNOWN
import com.microemp.ee_camera.EeCameraInterface


class EeCamera1 : EeCameraInterface {
	var view: FlutterView? = null
	var activity: Activity? = null
	var registrar: Registrar? = null

	var textureEntry: TextureRegistry.SurfaceTextureEntry? = null;

	var camera: Camera? = null

	var previewSize: Camera.Size? = null;
	var pictureSize: Camera.Size? = null;

	var takePictureCallback: Camera.PictureCallback? = null

	var currentOrientation:Int = ORIENTATION_UNKNOWN;
	var resolution: String = "high"

	var cameraPosition = Camera.CameraInfo.CAMERA_FACING_BACK;

	var isOpen: Boolean = false
	var isRecording: Boolean = false

	var enableAudio: Boolean = false

	var flutterTexture: TextureRegistry.SurfaceTextureEntry?= null


	val sizeTypes:Map<String, Int> = mapOf(
			"max" to -1, // 2160p
			"ultraHigh" to 3840, // 2160p
			"veryHigh" to 1920, // 1080p
			"high" to 1280, //720P
			"medium" to 640, // 480p
			"low" to 320 // QVGA
	)

	internal var mediaRecorder = MediaRecorder()

	constructor(registrar: Registrar,
				view: FlutterView,
				activity: Activity,
				textureEntry: TextureRegistry.SurfaceTextureEntry,
				resolution:String,
				cameraType:String,
				enableAudio:Boolean) {

		this.view = view;

		this.activity = activity
		this.registrar = registrar
		this.textureEntry = textureEntry;
		this.resolution = resolution;

		this.flutterTexture = view.createSurfaceTexture()

		this.enableAudio = enableAudio

		if (cameraType == "front"){
			cameraPosition = Camera.CameraInfo.CAMERA_FACING_FRONT
		}else{
			cameraPosition = Camera.CameraInfo.CAMERA_FACING_BACK
		}

		val orientationEventListener:OrientationEventListener = object :OrientationEventListener(activity.getApplicationContext()) {
			override fun onOrientationChanged(orientation: Int) {
				if (orientation == ORIENTATION_UNKNOWN) {
				  	return;
				}

				currentOrientation = (round(orientation / 90.0) * 90).toInt()
			}
        };

		orientationEventListener.enable();
	}

	fun writeBmp(path: String, bmp: Bitmap){
		try {
			val fout = FileOutputStream(path);
			val bos = BufferedOutputStream(fout);
			bmp.compress(Bitmap.CompressFormat.JPEG, 90, bos);
			bos.flush();
			bos.close();
		} catch (e: IOException) {
			e.printStackTrace();
		}
	}

	override fun ready(callback:()->Unit){
		callback()
	}

	override fun open(result: Result){
		openCamera(result);
	}

	private fun openCamera(result: Result){

		try {
			camera = Camera.open(cameraPosition);
		}catch (e:Exception){
			isOpen = false
			e.printStackTrace()
			return
		}

		camera!!.setErrorCallback({a,b->
			println("on error!!");
		})

		isOpen = true

		val rotate = getOrientation(this.activity, cameraPosition);

		val surfaceTexture = this.flutterTexture!!.surfaceTexture()

		camera!!.setPreviewTexture(surfaceTexture)

		this.previewSize = getCloselyPreSize(camera!!.parameters!!.supportedPreviewSizes!!, "high")
		this.pictureSize = getCloselyPreSize(camera!!.parameters!!.supportedPreviewSizes!!, this.resolution)

		val param = camera!!.parameters;
		param!!.setPreviewSize(this.previewSize!!.width, this.previewSize!!.height);
		param!!.setPictureSize(this.pictureSize!!.width, this.pictureSize!!.height);


		camera!!.parameters = param;

		camera!!.setDisplayOrientation(rotate);

		camera!!.startPreview()

		camera!!.autoFocus(null)

		val reply: MutableMap<String, String> = mutableMapOf("textureId" to this.flutterTexture!!.id().toString())
		reply.put("width", previewSize!!.width.toString())
		reply.put("height", previewSize!!.height.toString())
		reply.put("status","ok")
		reply.put("api","android_camera1")
		result.success(reply);
	}

	override fun takePhoto(savePath: String, result: Result){

		if (!isOpen){
			result.success("fail")
			return
		}

		this.takePictureCallback = Camera.PictureCallback { data, camera ->
			camera.stopPreview()

			var bitmap = BitmapFactory.decodeByteArray(data, 0, data.size)

			val rotate = getOrientation(this.activity, cameraPosition);

			val m = Matrix()
			m.setRotate(rotate.toFloat())

			bitmap = createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), m, true);

			writeBmp(savePath, bitmap);

			result.success("ok")
		}

		this.camera!!.takePicture(null, null, this.takePictureCallback);
	}

	override fun dispose(result: Result){
		isOpen = false
		isRecording = false

		if (camera != null) {
			camera!!.stopPreview();
			camera!!.release();
			camera = null;
		}

		result.success("ok")
	}

	fun getCloselyPreSize(sizeList: List<Camera.Size>, type: String): Camera.Size? {

		var th = 0
		if (sizeTypes.containsKey(type)){
			th = sizeTypes.getOrElse(type, {0})
		}

		val supportedSizes = ArrayList<Camera.Size>(sizeList)
		Collections.sort(supportedSizes, Comparator<Camera.Size> { a, b ->
			val aPixels = a.height * a.width
			val bPixels = b.height * b.width
			if (bPixels < aPixels) {
				return@Comparator -1
			} else if (bPixels > aPixels) {
				return@Comparator 1
			}
			0
		})

		//for (size in supportedSizes) {
			//println("sss:"+size.width + "/" + size.height.toString())
		//}

		// max
		if (th == -1){
			return supportedSizes.get(supportedSizes.size - 1)
		}

		for (size in supportedSizes) {
			if (size.width >= th) {
				return size
			}
		}

		return supportedSizes.get(0)
	}

	fun getOrientation(activity: Activity?, cameraId: Int) : Int {
		val info = Camera.CameraInfo()
		Camera.getCameraInfo(cameraId, info)
		val rotation = activity!!.windowManager!!.defaultDisplay!!.rotation

		var degrees = 0
		when (rotation) {
			Surface.ROTATION_0 -> degrees = 0
			Surface.ROTATION_90 -> degrees = 90
			Surface.ROTATION_180 -> degrees = 180
			Surface.ROTATION_270 -> degrees = 270
		}
		var result: Int
		if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {
			result = (info.orientation + degrees) % 360
			result = (360 - result) % 360   // compensate the mirror
		} else {
			// back-facing
			result = (info.orientation - degrees + 360) % 360
		}

		return result;
	}


	override fun startRecord(path: String, result: Result){
		if (!isOpen){
			result.success("fail")
			return
		}

		if (isRecording){
			result.success("fail")
			return
		}

		isRecording = true

		camera!!.unlock()
		mediaRecorder.reset()
		mediaRecorder.setCamera(camera);
		mediaRecorder.setVideoSource(MediaRecorder.VideoSource.CAMERA)
		mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
		mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
		mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
		mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)

		mediaRecorder.setVideoSize(this.pictureSize!!.width, this.pictureSize!!.height)
		mediaRecorder.setVideoEncodingBitRate(1280 * 1024)
		mediaRecorder.setOrientationHint(getOrientation(this.activity, cameraPosition))

		mediaRecorder.setOutputFile(path)

		try {
			mediaRecorder.prepare()
			mediaRecorder.start()

			result.success("ok")
		} catch (e: IOException) {
			e.printStackTrace()
			result.success("fail")
			return
		}

		return
	}

	override fun stopRecord(result: Result){

		if (!isOpen){
			result.success("fail")
			return
		}

		if (!isRecording){
			result.success("fail")
			return
		}

		isRecording = false

		mediaRecorder.setPreviewDisplay(null)
		mediaRecorder.setOnErrorListener(null);
		mediaRecorder.setOnInfoListener(null);
		try {
			mediaRecorder.stop()
			camera!!.lock()

			result.success("ok")

		} catch (e: IllegalStateException) {
			result.success("fail")
			e.printStackTrace()
		}
	}
}
