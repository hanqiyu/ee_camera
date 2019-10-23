import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ee_camera/ee_camera.dart';

void main() {
  const MethodChannel channel = MethodChannel('ee_camera');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await EeCamera.platformVersion, '42');
  });
}
