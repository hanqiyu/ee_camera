import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

class Video2 extends StatefulWidget {
	@override
	_Video2State createState() => _Video2State();
}

class _Video2State extends State<Video2> {

	VideoPlayerController _controller;

	@override
	void initState() {
		super.initState();

		initVideo();
	}

	initVideo() async{
		final Directory extDir = await getApplicationDocumentsDirectory();
		final String dirPath = '${extDir.path}/Pictures/flutter_test';

		print("file exs:"+File('${dirPath}/1571330078623.mp4').existsSync().toString());

		_controller = VideoPlayerController.file(File('${dirPath}/1571330078623.mp4'))
			..addListener((){
				if (_controller.value.hasError){
					print(_controller.value.errorDescription);
				}
			})
			..initialize().then((_) {
				_controller.play();
				setState(() {});
			});
	}

	@override
	void dispose() {
		super.dispose();
		_controller.dispose();
	}


	String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

	@override
	Widget build(BuildContext context) {

		return Scaffold(
			appBar: AppBar(
				title: Text('video'),
			),
			body: Container(
				child: Center(
					child: Container(
						color: Colors.black,
						child: Stack(
							children: <Widget>[
								_controller.value.initialized
								? AspectRatio(
									aspectRatio: _controller.value.aspectRatio,
									child: VideoPlayer(_controller),
								)
								: Container(),
								Positioned(
									bottom: 50,
									width: MediaQuery.of(context).size.width,
									child: Center(
										child: GestureDetector(
											onTapDown: (TapDownDetails e){
												_controller.play();
												print('play');
											},
											child: Container(
												width: 100,
												height: 100,
												child: CustomPaint(
													painter: ButtonPainter(rate: 1),
													size: Size(100, 100),
												),
											),
										),
									),
								)
							],
						),
					),
				),
			)
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
