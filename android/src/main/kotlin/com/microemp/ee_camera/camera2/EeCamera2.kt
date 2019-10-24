package com.microemp.ee_camera.camera2

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager

import android.media.MediaRecorder
import android.os.Build
import android.view.Surface
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.view.FlutterView
import io.flutter.view.TextureRegistry.SurfaceTextureEntry;

import java.io.File
import android.content.Context;
import android.graphics.ImageFormat
import android.hardware.camera2.*
import java.util.HashMap
import android.media.CamcorderProfile;
import android.media.ImageReader
import android.util.Size
import android.view.OrientationEventListener
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlin.math.round
import com.microemp.ee_camera.EeCameraInterface


class EeCamera2 : EeCameraInterface {
	var view: FlutterView? = null
	var activity: Activity? = null
	var registrar: PluginRegistry.Registrar? = null

	var textureEntry: SurfaceTextureEntry? = null;

	var cameraPermissionContinuation: Runnable? = null
	var isRequestPermission:Boolean = false;

	var cameraManager: CameraManager ?= null
	var cameraDevice: CameraDevice ?= null


	var captureSize: Size ?= null
	var previewSize: Size ?= null

	var captureProfile: CamcorderProfile ?= null
	var previewProfile: CamcorderProfile ?= null

	var pictureRecorder: ImageReader ?= null
	var mediaRecorder: MediaRecorder ?= null

	var captureRequestBuilder: CaptureRequest.Builder ?= null
	var cameraCaptureSession: CameraCaptureSession ?= null

	var flutterTexture: SurfaceTextureEntry ?= null

	var cameraTypes: HashMap<String, String> ?= null
	var cameraType: String = "back"

	var currentOrientation:Int = OrientationEventListener.ORIENTATION_UNKNOWN;
	var sensorOrientation:Int = 0
	var isFrontFacing: Boolean = false
	var orientationEventListener: OrientationEventListener ?= null

	var resolution : String = "high";

	var isOpen: Boolean = false
	var isRecording: Boolean = false

	var enableAudio:Boolean = false

	private lateinit var previewRequestBuilder: CaptureRequest.Builder

	constructor(registrar: PluginRegistry.Registrar,
				view: FlutterView,
				activity: Activity,
				textureEntry: SurfaceTextureEntry,
				resolution:String,
				cameraType:String,
				enableAudio:Boolean) {

		this.view = view;
		this.activity = activity
		this.registrar = registrar
		this.textureEntry = textureEntry;
		this.flutterTexture = view.createSurfaceTexture()
		this.resolution = resolution;

		this.cameraType = cameraType

		this.enableAudio = enableAudio

		this.isFrontFacing = this.cameraType == "front";
	}

	fun getOrientation() : Int {
		val  sensorOrientationOffset:Int;

		if (currentOrientation == OrientationEventListener.ORIENTATION_UNKNOWN){
			sensorOrientationOffset = 0
		}else{
			if (isFrontFacing){
				sensorOrientationOffset = -currentOrientation;
			}else{
				sensorOrientationOffset = currentOrientation;
			}
		}

		return (sensorOrientationOffset + sensorOrientation + 360) % 360;
	}

	fun writeFile(path: String, buffer: ByteBuffer) {
		val file = File(path)

		println("writeFile:"+path)
		println("writeFile buffer:"+buffer.toString())

		FileOutputStream(file).use { outputStream ->
			while (0 < buffer.remaining()) {
				outputStream.channel.write(buffer)
			}
		}
	}

	override fun ready(callback:()->Unit){

		cameraPermissionContinuation = Runnable {
			cameraPermissionContinuation = null
			isRequestPermission = true;
			callback()
		}

		this.registrar?.addRequestPermissionsResultListener(CameraRequestPermissionsListener())

		if (!this.hasCameraPermission()) {
			//Android M需要运行时权限
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {

				var permissions = arrayOf(Manifest.permission.CAMERA);

				if (this.enableAudio){
					permissions = arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)
				}

				this.registrar?.activity()?.requestPermissions(permissions, 990)
			}

			isRequestPermission = true;
		} else {
			isRequestPermission = true;
			callback()
		}
	}

	private fun hasCameraPermission(): Boolean {
		return Build.VERSION.SDK_INT < Build.VERSION_CODES.M
				|| this.activity?.checkSelfPermission(Manifest.permission.CAMERA) === PackageManager.PERMISSION_GRANTED
	}

	private inner class CameraRequestPermissionsListener : PluginRegistry.RequestPermissionsResultListener {
		override fun onRequestPermissionsResult(id: Int, permissions: Array<String>, grantResults: IntArray): Boolean {

			cameraPermissionContinuation?.run()

			return false
		}
	}

	fun  getProfile(cameraId:Int, type: String):CamcorderProfile {

		val vType = type

		if (vType == "max" && CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_HIGH)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_HIGH)
		}
		if (vType == "ultraHigh" && CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_2160P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_2160P)
		}
		if (vType == "veryHigh" && CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_1080P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_1080P)
		}
		if (vType == "high" && CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_720P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_720P)
		}
		if (vType == "medium" && CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P)
		}
		if (vType == "low" && CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
		}

		// auto
		if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_HIGH)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_HIGH)
		}
		if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_2160P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_2160P)
		}
		if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_1080P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_1080P)
		}
		if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_720P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_720P)
		}
		if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_480P)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_480P)
		}
		if (CamcorderProfile.hasProfile(cameraId, CamcorderProfile.QUALITY_QVGA)) {
			return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_QVGA)
		}

		return CamcorderProfile.get(cameraId, CamcorderProfile.QUALITY_LOW)
	}

	fun getCameraTypeMap(): HashMap<String, String> {
		val cameraNames = cameraManager!!.cameraIdList
		val cameraAll = HashMap<String, String>()

		for (cameraName in cameraNames) {
			val characteristics = cameraManager!!.getCameraCharacteristics(cameraName)
			val lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING)!!

			if (lensFacing == CameraMetadata.LENS_FACING_FRONT){
				cameraAll["front"] = cameraName
			}else if (lensFacing == CameraMetadata.LENS_FACING_BACK){
				cameraAll["back"] = cameraName
			}
		}

		return cameraAll
	}

	override fun open(result: MethodChannel.Result){

		cameraManager = this.activity!!.getSystemService(Context.CAMERA_SERVICE) as CameraManager

		this.cameraTypes = this.getCameraTypeMap()

		orientationEventListener = object :OrientationEventListener(activity!!.getApplicationContext()) {
			override fun onOrientationChanged(orientation: Int) {
				if (orientation == ORIENTATION_UNKNOWN) {
					return;
				}

				currentOrientation = (round(orientation / 90.0) * 90).toInt()
			}
		}

		orientationEventListener!!.enable();

		val characteristics = cameraManager!!.getCameraCharacteristics(this.cameraTypes!![this.cameraType].toString())

		sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);

		captureProfile = this.getProfile(this.cameraTypes!![this.cameraType]!!.toInt(), this.resolution)
		previewProfile = this.getProfile(this.cameraTypes!![this.cameraType]!!.toInt(), "high")

		captureSize = Size(captureProfile!!.videoFrameWidth, captureProfile!!.videoFrameHeight)
		previewSize = Size(previewProfile!!.videoFrameWidth, previewProfile!!.videoFrameHeight)

		openCamera(result);

	}

	private fun openCamera(result: MethodChannel.Result){

		pictureRecorder = ImageReader.newInstance(captureSize!!.width, captureSize!!.height, ImageFormat.JPEG, 2)
		cameraManager = activity?.getSystemService(Context.CAMERA_SERVICE) as CameraManager

		if (cameraDevice != null) {
			cameraDevice!!.close()
		}

		cameraManager?.openCamera(this.cameraTypes!![this.cameraType].toString(), object : CameraDevice.StateCallback() {

			override fun onOpened(device: CameraDevice) {
				cameraDevice = device
				startPreview()
				isOpen = true

				val reply: MutableMap<String, String> = mutableMapOf("textureId" to flutterTexture!!.id().toString())
				reply.put("width", previewSize!!.width.toString())
				reply.put("height", previewSize!!.height.toString())
				reply.put("status","ok")
				reply.put("api","android_camera2")
				result.success(reply);
			}

			override fun onDisconnected(device: CameraDevice) {
				device.close()

				isOpen = false
			}

			override fun onError(device: CameraDevice, error: Int) {
				device.close()
			}

		}, null);

	}

	override fun takePhoto(savePath: String, result: MethodChannel.Result){
		if (!isOpen){
			result.success("fail")
			return
		}

		pictureRecorder!!.setOnImageAvailableListener({ imageReader ->
			val image = imageReader.acquireLatestImage()
			val buffer = image.planes[0].buffer

			writeFile(savePath, buffer)
		}, null)

		val captureBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
		captureBuilder.addTarget(pictureRecorder!!.surface)
		captureBuilder.set(CaptureRequest.JPEG_ORIENTATION, getOrientation())

		cameraCaptureSession!!.capture(captureBuilder.build(), object :CameraCaptureSession.CaptureCallback() {
			override fun onCaptureFailed(session: CameraCaptureSession, request: CaptureRequest, failure: CaptureFailure) {
				super.onCaptureFailed(session, request, failure)

				var reason = ""

				if (failure.reason == CaptureFailure.REASON_ERROR){
					reason = "An error happened in the framework"
				}else if (failure.reason == CaptureFailure.REASON_FLUSHED){
					reason = "The capture has failed due to an abortCaptures() call"
				}else {
					reason = "Unknown reason"
				}
			}

			override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, r: TotalCaptureResult) {
				super.onCaptureCompleted(session, request, r)

				result.success("ok")
			}

		}, null)
	}

	fun closeCaptureSession(){
		if (cameraCaptureSession != null) {
			cameraCaptureSession!!.close();
			cameraCaptureSession = null;
		}
	}

	fun close() {
		isOpen = false

		closeCaptureSession();

		if (cameraDevice != null) {
			cameraDevice!!.close();
			cameraDevice = null;
		}

		if (pictureRecorder != null) {
			pictureRecorder!!.close();
			pictureRecorder = null;
		}

		if (mediaRecorder != null) {
			mediaRecorder!!.reset();
			mediaRecorder!!.release();
			mediaRecorder = null;
		}
	}

	override fun dispose(result: MethodChannel.Result){
		isOpen = false
		isRecording = false

		close();
		flutterTexture!!.release();
		orientationEventListener!!.disable();

		result.success("ok")
	}

	private fun startPreview() {
		if (cameraDevice == null) return

		try {
			cameraCaptureSession?.close()
			cameraCaptureSession = null

			val texture = this.flutterTexture!!.surfaceTexture()
			texture!!.setDefaultBufferSize(previewSize!!.width, previewSize!!.height)

			previewRequestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)

			val previewSurface = Surface(texture)
			previewRequestBuilder.addTarget(previewSurface)

			cameraDevice?.createCaptureSession(listOf(previewSurface),
					object : CameraCaptureSession.StateCallback() {

						override fun onConfigured(session: CameraCaptureSession) {
							cameraCaptureSession = session
							previewRequestBuilder!!.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
							cameraCaptureSession!!.setRepeatingRequest(previewRequestBuilder!!.build(), null, null)
						}

						override fun onConfigureFailed(session: CameraCaptureSession) {

						}
					}, null)
		} catch (e: CameraAccessException) {
			println(e.toString())
		}

	}

	override fun startRecord(path: String, result: MethodChannel.Result){
		if (!isOpen){
			result.success("fail")
			return
		}

		if (isRecording){
			result.success("fail")
			return
		}

		println("start record")

		isRecording = true

		prepareMediaRecorder(path)

		cameraCaptureSession?.stopRepeating()
		cameraCaptureSession?.abortCaptures()
		cameraCaptureSession?.close()
		cameraCaptureSession = null


		val texture = this.flutterTexture!!.surfaceTexture()
		texture!!.setDefaultBufferSize(captureSize!!.width, captureSize!!.height)
		val previewSurface = Surface(texture)

		val recorderSurface = mediaRecorder!!.surface
		val surfaces = ArrayList<Surface>().apply {
			add(previewSurface)
			add(recorderSurface)
		}

		previewRequestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
			addTarget(previewSurface)
			addTarget(recorderSurface)
		}

		cameraDevice?.createCaptureSession(surfaces,
				object : CameraCaptureSession.StateCallback() {

					override fun onConfigured(session: CameraCaptureSession) {
						cameraCaptureSession = session
						previewRequestBuilder!!.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
						cameraCaptureSession!!.setRepeatingRequest(previewRequestBuilder!!.build(), null, null)

						mediaRecorder?.start()
					}

					override fun onConfigureFailed(cameraCaptureSession: CameraCaptureSession) {

					}
				}, null)

		result.success("ok")
	}

	override fun stopRecord(result: MethodChannel.Result){
		if (!isOpen){
			result.success("fail")
			return
		}

		if (!isRecording){
			result.success("fail")
			return
		}

		println("stop record")

		if (cameraCaptureSession != null) {
			cameraCaptureSession!!.stopRepeating()
			cameraCaptureSession!!.abortCaptures()
		}

		mediaRecorder!!.setOnErrorListener(null)

		mediaRecorder!!.stop()
		mediaRecorder!!.reset()
		startPreview()

		isRecording = false

		result.success("ok")
	}

	private fun prepareMediaRecorder(outputFilePath: String) {
		if (mediaRecorder != null) {
			mediaRecorder!!.release()
		}

		mediaRecorder = MediaRecorder()

		mediaRecorder!!.setVideoSource(MediaRecorder.VideoSource.SURFACE)

		mediaRecorder!!.setAudioSource(MediaRecorder.AudioSource.MIC)
		mediaRecorder!!.setOutputFormat(captureProfile!!.fileFormat)
		mediaRecorder!!.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
		/* 注意：setAudioEncoder()应在setOutputFormat()之后，否者会出现setAudioEncoder called in an invalid state(2)的错误 */
		/* 上面三个顺序别乱...*/

		mediaRecorder!!.setVideoEncoder(captureProfile!!.videoCodec)
		//mediaRecorder!!.setVideoEncodingBitRate(captureProfile!!.videoBitRate) //大约是3000多k
		mediaRecorder!!.setVideoEncodingBitRate(1280 * 1024)
		mediaRecorder!!.setAudioSamplingRate(captureProfile!!.audioSampleRate)
		mediaRecorder!!.setVideoFrameRate(captureProfile!!.videoFrameRate)
		mediaRecorder!!.setVideoSize(captureSize!!.width, captureSize!!.height)
		mediaRecorder!!.setOutputFile(outputFilePath)
		mediaRecorder!!.setOrientationHint(getOrientation())

		mediaRecorder!!.prepare()
	}

}
