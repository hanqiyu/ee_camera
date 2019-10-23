import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

enum ResolutionPreset {
  /// 352x288 on iOS, 240p (320x240) on Android
  low,

  /// 480p (640x480 on iOS, 720x480 on Android)
  medium,

  /// 720p (1280x720)
  high,

  /// 1080p (1920x1080)
  veryHigh,

  /// 2160p (3840x2160)
  ultraHigh,

  /// The highest resolution available.
  max,
}

enum CameraType {
  back,
  front,
}

String serializeResolutionPreset(ResolutionPreset resolutionPreset) {
	switch (resolutionPreset) {
		case ResolutionPreset.max:
			return 'max';
		case ResolutionPreset.ultraHigh:
			return 'ultraHigh';
		case ResolutionPreset.veryHigh:
			return 'veryHigh';
		case ResolutionPreset.high:
			return 'high';
		case ResolutionPreset.medium:
			return 'medium';
		case ResolutionPreset.low:
			return 'low';
	}
	throw ArgumentError('Unknown ResolutionPreset value');
}

class EeCamera {
	static const MethodChannel _channel = const MethodChannel('ee_camera');

	static Future<String> get platformVersion async {
		final String version = await _channel.invokeMethod('getPlatformVersion');
		return version;
	}

	static Future<String> get test async {
		final String test = await _channel.invokeMethod('test');
		return test;
	}
}

class EeCameraController {

	EeCameraController({
		@required this.resolutionPreset,
		@required this.cameraType,
		this.enableAudio = false
	});

	bool isInitialized = false;
	bool enableAudio = false;
	int textureId;
	Completer<void> _creatingCompleter;

	ResolutionPreset resolutionPreset;
	CameraType cameraType;

	String apiName;

	int width;
	int height;
	double ratio = 1.0;

	static Future<String> test() async {
		final String version = await EeCamera._channel.invokeMethod('test');
		return version;
	}

	Future<void> takePhoto(String path) async {
		final String reply = await EeCamera._channel.invokeMethod(
			'takePhoto',
			<String, dynamic>{'path': path},
		);
		return reply;
	}

	Future<void> startRecord(String path) async {
		final String reply = await EeCamera._channel.invokeMethod(
			'startRecord',
			<String, dynamic>{'path': path},
		);
		return reply;
	}

	Future<void> stopRecord() async {

		print('kkk stop');
		final String reply = await EeCamera._channel.invokeMethod(
			'stopRecord',
			null,
		);
		print(reply);
		return reply;
	}

	Future<void> dispose() async {
		if (textureId == null){
			return null;
		}

		final String reply = await EeCamera._channel.invokeMethod(
			'dispose',
			<String, dynamic>{'textureId': textureId},
		);
		return reply;
	}

	Future<void> initialize() async {

		try {
			_creatingCompleter = Completer<void>();

			final Map<dynamic, dynamic> reply = await EeCamera._channel.invokeMethod(
				'initialize',
				<String, dynamic>{
					'resolution': serializeResolutionPreset(resolutionPreset),
					'type': cameraType == CameraType.front ? "front" : "back",
					'enableAudio': enableAudio ? "Y" : "N",
				},
			);

			print(reply);

			textureId = int.parse('${reply['textureId']}');
			textureId = int.parse('${reply['textureId']}');

			apiName = '${reply['api']}';

			if ('${reply['status']}' == 'ok'){
				isInitialized = true;
			}

			this.width = double.parse('${reply['width']}').toInt();
			this.height = double.parse('${reply['height']}').toInt();

			this.ratio = this.height / this.width;
		} on PlatformException catch (e) {

		}

		_creatingCompleter.complete();
		return _creatingCompleter.future;
	}
}


class EeCameraPreview extends StatelessWidget {

	final EeCameraController controller;

	const EeCameraPreview(this.controller);

	@override
	Widget build(BuildContext context) {
		return controller.isInitialized
			? Texture(
			textureId: controller.textureId
		)
			: Container();
	}
}