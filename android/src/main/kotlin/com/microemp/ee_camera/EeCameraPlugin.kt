package com.microemp.ee_camera

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.view.FlutterView
import android.os.Bundle
import io.flutter.view.TextureRegistry
import android.app.Application.ActivityLifecycleCallbacks
import android.os.Build


import com.microemp.ee_camera.camera1.EeCamera1
import com.microemp.ee_camera.camera2.EeCamera2

class EeCameraPlugin: MethodCallHandler {
	var view: FlutterView? = null
	var activity: Activity? = null
	var registrar: Registrar? = null

	var cameraType: String = "1"


	var textureEntry: TextureRegistry.SurfaceTextureEntry? = null;

	var camera1: EeCamera1? = null;
	var camera2: EeCamera2? = null;

	var activityLifecycleCallbacks: ActivityLifecycleCallbacks? = null

	companion object {
		@JvmStatic
		fun registerWith(registrar: Registrar) {
			val channel = MethodChannel(registrar.messenger(), "ee_camera")
			channel.setMethodCallHandler(EeCameraPlugin(registrar, registrar.view(), registrar.activity()))
		}
	}

	private constructor(registrar: Registrar, view: FlutterView, activity: Activity) {
		this.view = view;
		this.activity = activity
		this.registrar = registrar
		this.textureEntry = this.view?.createSurfaceTexture();


		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
			this.cameraType = "2"
		}else{
			this.cameraType = "1"
		}

		//this.cameraType = "2"

		println("cameraType:" + this.cameraType);

		this.activityLifecycleCallbacks = object : ActivityLifecycleCallbacks {
			override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle) {}

			override fun onActivityStarted(activity: Activity) {}

			override fun onActivityResumed(activity: Activity) {
				/*
				if (activity === this@EeCameraPlugin.activity) {

					if (this@EeCameraPlugin.isRequestPermission) {
						//openCamera();
					}
				}
				*/
			}

			override fun onActivityPaused(activity: Activity) {
				/*
				if (activity === this@EeCameraPlugin.activity) {
					if (camera1 != null) {
						camera1!!.dispose();
						camera1 = null;
					}
				}
				*/

			}

			override fun onActivityStopped(activity: Activity) {
				/*
				if (activity === this@EeCameraPlugin.activity) {
					if (camera1 != null) {
						camera1!!.dispose();
						camera1 = null;
					}
				}
				*/

			}

			override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
			override fun onActivityDestroyed(activity: Activity) {}
		}

		this.activity!!.application?.registerActivityLifecycleCallbacks(this.activityLifecycleCallbacks);
	}


	private fun open(result: Result) {


		if (this.cameraType == "1"){
			camera1!!.open(result)
		}else{
			camera2!!.open(result)
		}
	}

	override fun onMethodCall(call: MethodCall, result: Result) {

		println("flutter methid:"+call.method)

		if (call.method == "getPlatformVersion") {
			result.success("Android ${android.os.Build.VERSION.RELEASE}")
		}else if (call.method == "test"){
			result.success("test!")
		} else if (call.method == "initialize") {
			val resolution: String? = call.argument("resolution");
			val cameraType: String? = call.argument("type");
			val audio: String? = call.argument("enableAudio");
			var enableAudio : Boolean = false

			if (audio == "Y"){
				enableAudio = true
			}

			if (this.cameraType == "1") {
				if (camera1 == null) {
					camera1 = EeCamera1(this.registrar!!, this.view!!, this.activity!!, this.textureEntry!!, resolution!!, cameraType!!, enableAudio);
				}

				camera1!!.ready {
					this.open(result)
				}
			}else{
				if (camera2 == null) {
					camera2 = EeCamera2(this.registrar!!, this.view!!, this.activity!!, this.textureEntry!!, resolution!!, cameraType!!, enableAudio);
				}

				camera2!!.ready {
					this.open(result)
				}
			}
		} else if (call.method == "takePhoto") {

			val savePath: String? = call.argument("path");

			if (this.cameraType == "1") {
				camera1!!.takePhoto(savePath!!, result)
			} else {
				camera2!!.takePhoto(savePath!!, result)
			}
		}else if (call.method == "startRecord") {

			val savePath: String? = call.argument("path");

			if (this.cameraType == "1") {
				camera1!!.startRecord(savePath!!, result)
			}else{
				camera2!!.startRecord(savePath!!, result)
			}
		}else if (call.method == "stopRecord") {

			if (this.cameraType == "1") {
				camera1!!.stopRecord(result)
			}else{
				camera2!!.stopRecord(result)
			}
		} else if (call.method == "dispose") {
			if (this.cameraType == "1") {
				camera1?.dispose(result)
				camera1 = null
			} else {
				camera2?.dispose(result)
				camera2 = null
			}

			if (this.activity != null && this.activityLifecycleCallbacks != null) {
				this.activity
						?.getApplication()
						?.unregisterActivityLifecycleCallbacks(this.activityLifecycleCallbacks);
			}

		}else if (call.method == "prepareRecord") {
			// ios独有优化
			result.success("ok");
		} else {
			result.notImplemented()
		}
	}
}


