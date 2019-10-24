package com.microemp.ee_camera

import io.flutter.plugin.common.MethodChannel

interface EeCameraInterface{
	fun takePhoto(savePath: String, result: MethodChannel.Result)
	fun startRecord(path: String, result: MethodChannel.Result)
	fun stopRecord(result: MethodChannel.Result)
	fun dispose(result: MethodChannel.Result)
	fun open(result: MethodChannel.Result)
	fun ready(callback:()->Unit)
}