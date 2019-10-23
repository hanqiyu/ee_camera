import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:ee_camera/ee_camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class CaptureHelp{

	static push(BuildContext context){
		Navigator.push(context, PageRouteBuilder(
			opaque: false,
			pageBuilder: (BuildContext context, _, __) {
				return Capture();
			},
			transitionsBuilder: (___, Animation<double> animation, ____, Widget child) {
				return SlideTransition(
					position: Tween<Offset>(
						begin: const Offset(0.0, 1.0),
						end: Offset.zero
					).animate(animation),
					child: child,
				);
			}
		));
	}
}

class Capture extends StatefulWidget {
	@override
	_CaptureState createState() => _CaptureState();
}

class _CaptureState extends State<Capture> {

	CameraDocker _cameraDocker;
	CameraDocker get cameraDocker{
		if (_cameraDocker == null){
			_cameraDocker = CameraDocker();
		}

		return _cameraDocker;
	}

	VideoDocker _videoDocker;
	VideoDocker get videoDocker{
		if (_videoDocker == null){
			_videoDocker = VideoDocker();
		}

		return _videoDocker;
	}

	bool recordFinish = false;

	@override
	void initState() {
		super.initState();

		//todo temp
		//this.videoDocker.setVideo("");
		//recordFinish = true;
	}

	@override
	void dispose() {
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {

		return Scaffold(
			body: Container(
				child: NotificationListener<_CaptureNotify>(
					onNotification: (_CaptureNotify n){

						if (n.type == 'stop_record'){
							if (_videoDocker!= null){
								_videoDocker.closeVideo();
							}
							_videoDocker = null;
							this.videoDocker.setVideo(n.path);
							recordFinish = true;
						}else if (n.type == 'back_camera'){
							_cameraDocker = null;
							this.cameraDocker.initCamera();
							recordFinish = false;
						}

						setState(() {  });

						return true;
					},
					child: recordFinish ? this.videoDocker.widget : this.cameraDocker.widget
				),
			)
		);
	}
}

class _CaptureNotify extends Notification{

	String path;
	String type;

	_CaptureNotify({
		this.type,
		this.path,
	});
}

class CameraDocker{
	Camera widget;
	_CameraState state;

	initCamera(){
		state.initCamera();
	}

	CameraDocker(){
		state = _CameraState();
		widget = Camera(docker: this,);
	}
}


class Camera extends StatefulWidget {
	final CameraDocker docker;

	Camera({@required this.docker}):super();

	@override
	_CameraState createState(){
		return docker.state;
	}
}

class _CameraState extends State<Camera> {

	int runMs = 0;
	int stepMs = 50;
	int totalSecond = 10;
	Timer startTimer;
	Timer recordTimer;
	bool isRecording = false;

	String error;

	String videoPath;

	EeCameraController _controller;

	CameraType cameraType;

	@override
	void initState() {
		super.initState();

		cameraType = CameraType.back;

		initCamera();
	}

	@override
	void dispose() {
		super.dispose();

		if (_controller != null){
			_controller.dispose();
		}
	}

	initCamera() async{
		if (_controller != null){
			await _controller.dispose();
		}

		if (!mounted){
			return;
		}

		_controller = EeCameraController(resolutionPreset:ResolutionPreset.medium,cameraType: cameraType, enableAudio: true);

		await _controller.initialize();
		error = null;

		setState(() { });
	}

	startRecord() async{
		error = null;
		if (!_controller.isInitialized){
			error = '摄像机未准备好';
			setState(() { });
			return;
		}

		if (isRecording){
			error = '已经在录像中了';
			setState(() { });
			return;
		}

		isRecording = true;

		final Directory extDir = await getApplicationDocumentsDirectory();
		final String dirPath = '${extDir.path}/Pictures/flutter_test';
		await Directory(dirPath).create(recursive: true);
		final String filePath = '$dirPath/${timestamp()}.mp4';

		_controller.startRecord(filePath);

		print(filePath);

		this.videoPath = filePath;

		recordTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer){
			runMs += stepMs;
			setState(() {});
			
			// 加600ms的缓冲
			if (runMs >= totalSecond * 1000 + 600){
				timer.cancel();
				stopRecord();
			}
		});
	}

	stopRecord() async{
		error = null;
		if (!_controller.isInitialized){
			error = '摄像机未准备好';
			setState(() { });
			return;
		}

		if (!isRecording){
			error = '不在录像中';
			setState(() { });
			return;
		}

		isRecording = false;

		// 一定要等待结束完成后, 不然可能video预览会出错
		await _controller.stopRecord();

		recordTimer = null;
		runMs = 0;
		setState(() {});

		_CaptureNotify(type: "stop_record", path: this.videoPath).dispatch(context);
	}

	switchCamera() async{
		error = null;
		if (_controller != null){
			await _controller.dispose();
		}

		if (cameraType == CameraType.back){
			cameraType = CameraType.front;
		}else{
			cameraType = CameraType.back;
		}

		_controller = EeCameraController(resolutionPreset:ResolutionPreset.medium,cameraType: cameraType, enableAudio: true);

		await _controller.initialize();

		setState(() { });
	}

	String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

	@override
	Widget build(BuildContext context) {

		return Container(
			color: Colors.black,
			child: Stack(
				children: <Widget>[
					//Container(color: Colors.grey,),
					Center(
						child: LayoutBuilder(builder: (BuildContext buildContext, BoxConstraints boxConstraints){
							double w = boxConstraints.maxWidth;
							double h = w / _controller.ratio;
							return Container(
								color: Colors.black,
								width: w,
								height: h,
								child: EeCameraPreview(_controller),
							);
						}),
					),
					Positioned(
						top: 50,
						width: MediaQuery.of(context).size.width,
						child: Row(
							children: <Widget>[
								Expanded(
									child: Container(
										padding: EdgeInsets.all(10),
										child: error != null ? Text(error, style: TextStyle(color: Colors.red, fontSize: 11),) : Container(),
									),
								),
								GestureDetector(
									onTap: (){
										switchCamera();
									},
									child: Container(
										color: Colors.transparent,
										padding: EdgeInsets.all(10),
										child: Icon(IconData(0xf49e, fontFamily: CupertinoIcons.iconFont, fontPackage: CupertinoIcons.iconFontPackage), size:32.0, color: Colors.white,) ,
									),
								)
							],
						)
					),
					Positioned(
						bottom: 50,
						width: MediaQuery.of(context).size.width,
						child: Center(
							child: Container(
								width: 240,
								child: Row(
									children: <Widget>[
										GestureDetector(
											onTap: (){
												Navigator.of(context).pop();
											},
											child: Container(
												color: Colors.transparent,
												width: 40,
												padding: EdgeInsets.only(top: 20),
												margin: EdgeInsets.only(right: 10),
												child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 44,),
											),
										),
										Column(
											children: <Widget>[
												Container(
													height: 25,
													width: 140,
													child: Text(
														"按住开始录像, 松开结束",
														textAlign: TextAlign.center,
														style: TextStyle(
															color: Colors.white,
															fontSize: 11,
															
														),
													),
												),
												Container(
													child: Listener(
														onPointerDown: (PointerDownEvent e){
															if (startTimer != null){
																startTimer.cancel();
																startTimer = null;
															}

															startTimer = Timer.periodic(Duration(milliseconds: 200), (timer){
																timer.cancel();
																this.startRecord();
															});
														},
														onPointerUp: (PointerUpEvent e){
															if (startTimer != null){
																startTimer.cancel();
																startTimer = null;
															}
															if (recordTimer != null){
																recordTimer.cancel();
															}

															this.stopRecord();
														},
														child: Container(
															width: 140,
															height: 100,
															child: Center(
																child: CustomPaint(
																	painter: ButtonPainter(rate: runMs / (totalSecond * 1000)),
																	size: Size(100, 100),
																),
															),
														),
													),
												),
											],
										),
										Container(
											width: 50,
										),
									],
								),
							),
						),
					)
				],
			),
		);
	}
}

class ButtonPainter extends CustomPainter {

	double rate;

	ButtonPainter({@required this.rate});

	@override
	void paint(Canvas canvas, Size size) {

		final borderPaint = Paint()
			..color = Colors.lightGreen[400]
			..style = PaintingStyle.fill;

		canvas.drawCircle(Offset(50, 50), 50, borderPaint);

		final borderPaint3 = Paint()
			..color = Colors.grey[300]
			..style = PaintingStyle.fill;

		double r = rate;

		if (r  > 1){
			r = 1;
		}

		double p = 2 - 2 * r;
		canvas.drawArc(Rect.fromCircle(center: Offset(50, 50), radius: 50), ( - 0.5 * pi), (-p * pi), true, borderPaint3);

		final borderPaint2 = Paint()
			..color = Colors.white
			..style = PaintingStyle.fill;

		canvas.drawCircle(Offset(50, 50), 42, borderPaint2);
	}

	@override
	bool shouldRepaint(CustomPainter oldDelegate) {
		return true;
	}
}



class VideoDocker{
	Video widget;
	_VideoState state;

	setVideo(String path){
		state.setVideo(path);
	}

	closeVideo(){
		state.closeVideo();
	}

	VideoDocker(){
		state = _VideoState();
		widget = Video(docker: this,);
	}
}


class Video extends StatefulWidget {

	final VideoDocker docker;

	Video({this.docker});

	@override
	_VideoState createState(){
		return this.docker.state;
	}
}

class _VideoState extends State<Video> {

	VideoPlayerController _controller;

	@override
	void initState() {
		super.initState();
	}

	@override
	void dispose() async{
		super.dispose();
		this.closeVideo();
	}

	closeVideo() async{
		if (_controller != null){
			await _controller.dispose();
			_controller = null;
		}
	}

	setVideo(String path) async{
		if (_controller != null){
			await _controller.dispose();
			_controller = null;
		}

		_controller = VideoPlayerController.file(File(path))
			..addListener((){
				if (_controller.value.hasError) {
					print(_controller.value.errorDescription);
				}
			})
			..initialize().then((_) {
				_controller.setLooping(true);
				_controller.play();
				setState(() {});
			});
	}

	String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

	@override
	Widget build(BuildContext context) {

		return Container(
			color: Colors.black,
			child: Stack(
				children: <Widget>[
					Container(),
					Center(
						child: _controller.value.initialized ?
						AspectRatio(
							aspectRatio: _controller.value.aspectRatio,
							child: VideoPlayer(_controller),
						): 
						Container(),
					),
					Positioned(
						top: 50,
						width: MediaQuery.of(context).size.width,
						child: Row(
							children: <Widget>[
								GestureDetector(
									onTap: (){
										_CaptureNotify(type: "back_camera").dispatch(context);
									},
									child: Container(
										color: Colors.transparent,
										padding: EdgeInsets.all(10),
										child: Icon(Icons.arrow_back_ios, size:18.0, color: Colors.white,) ,
									),
								),
								Expanded(
									child: Container(),
								),
							],
						)
					),
					Positioned(
						bottom: 50,
						width: MediaQuery.of(context).size.width,
						child: Row(
							children: <Widget>[
								Expanded(
									child: Container(
										margin: EdgeInsets.only(left: 20),
										child: _controller.value.initialized ? Text('视频长度:${_controller.value.duration.inSeconds}秒', style: TextStyle(color: Colors.white, fontSize: 11),) : Container(),
									),
								),
								Container(
									margin: EdgeInsets.only(right: 20),
									padding: EdgeInsets.only(right: 6, left: 6, top: 4, bottom: 4),
									decoration: BoxDecoration(
										color: Colors.green,
										borderRadius: BorderRadius.all(Radius.circular(4)),
									),
									child: Text("使用", style: TextStyle(color: Colors.white, fontSize: 14),),
								)
							],
						),
					)
				],
			),
		);
	}
}