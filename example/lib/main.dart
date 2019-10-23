/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

List<CameraDescription> cameras;

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(CameraApp());
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController controller;

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
	  print('caca222');
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_)async {
      if (!mounted) {
        return;
      }
      setState(() {});

	  //return;

	  final Directory extDir = await getApplicationDocumentsDirectory();
	final String dirPath = '${extDir.path}/Pictures/flutter_test';
	await Directory(dirPath).create(recursive: true);
	final String filePath = '$dirPath/${timestamp()}.mp4';

	controller.startVideoRecording(filePath);

	Future.delayed(Duration(seconds: 10), () async{
		print(filePath);
		controller.stopVideoRecording();
	});
	});
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return AspectRatio(
        aspectRatio:
        controller.value.aspectRatio,
        child: CameraPreview(controller));
  }
}
*/


/*
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';

import './capture.dart';
import './video.dart';
import 'package:ee_camera/ee_camera.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
	@override
	_MyAppState createState() => _MyAppState();
}


class _MyAppState extends State<MyApp> {

	EeCameraController _controller;

	bool done = false;
	String rrr = '';

	@override
	void initState() {
		super.initState();

		done = false;

		rrr = 'ok';

		initCamera();
	}

	initCamera() async {
		_controller = EeCameraController(resolutionPreset:ResolutionPreset.medium,cameraType: CameraType.back, enableAudio: true);

		await _controller.initialize();

		setState(() { });
		

		Future.delayed(Duration(seconds: 1), () async{
			final Directory extDir = await getApplicationDocumentsDirectory();
			final String dirPath = '${extDir.path}/Pictures/flutter_test';
			await Directory(dirPath).create(recursive: true);
			final String filePath = '$dirPath/aaa.mp4';

			_controller.startRecord(filePath);

			Future.delayed(Duration(seconds: 6), () async{
				print(filePath);
				await _controller.stopRecord();
				print('stop done');

				done = true;

				var ff = File(filePath);

				var e =  await ff.exists();
				var s =  await ff.length();

				rrr = "ok, exists:${e}, size:${s}, api:${_controller.apiName}";

				setState(() {
				  
				});

				

				Map<String, dynamic> data = {
					'file': UploadFileInfo(File(filePath), "xxx.mp4"),
				};

				String url = "http://62.234.105.215/upload_temp.php";

				

				Dio dio = new Dio();
				FormData formData = new FormData.from(data);

				Response response = await dio.post(url, data: formData, options: Options(
					connectTimeout:5000,
					receiveTimeout:5000,
					//responseType: ResponseType.PLAIN,
				));

				print(response);

				rrr = 'ok, exists:${e}, size:${s}, api:${_controller.apiName}, response:${response.data}';
				setState(() {
				  
				});
					
					
			});
		});
	}

	@override
	Widget build(BuildContext context) {
		
		return MaterialApp(
			debugShowCheckedModeBanner: false,
			home: Scaffold(
				body: Builder(builder: (BuildContext context){
					return Container(
						child: !done ? Center(
							child: LayoutBuilder(builder: (BuildContext buildContext, BoxConstraints boxConstraints){
								double ratio = 1.0;
								if (_controller.isInitialized){
									ratio = _controller.ratio;
								}
								double w = boxConstraints.maxWidth;
								double h = w / ratio;
								return Container(
									color: Colors.black,
									width: w,
									height: h,
									child: EeCameraPreview(_controller),
								);
							}),
						): Center( child:Text(rrr) ),
					);
				})
				//body: Camera()
			),
		);
	}
}
*/


import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import './capture.dart';
import './video.dart';
import 'package:ee_camera/ee_camera.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
	@override
	_MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

	@override
	void initState() {
		super.initState();
	}

	@override
	Widget build(BuildContext context) {
		
		return MaterialApp(
			debugShowCheckedModeBanner: false,
			home: Scaffold(
				body: Builder(builder: (BuildContext context){
					return Container(
						child: GestureDetector(
							onTap: (){
								
								/*
								Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context){
									return FlutterCamera();
								}));
								*/
								

								CaptureHelp.push(context);
							},
							child: Center(
								child: Container(
									width: 200,
									height: 100,
									color: Colors.black,
									//child: Video2(),
								),
							),
						),
					);
				})
				//body: Camera()
			),
		);
	}
}

