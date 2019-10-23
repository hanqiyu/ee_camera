#import "EeCameraPlugin.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <CoreMotion/CoreMotion.h>
#import <libkern/OSAtomic.h>

static FlutterError *getFlutterError(NSError *error) {
	return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %d", (int)error.code]
							   message:error.localizedDescription
							   details:error.domain];
}

@interface FLTSavePhotoDelegate : NSObject <AVCapturePhotoCaptureDelegate>
@property(readonly, nonatomic) NSString *path;
@property(readonly, nonatomic) FlutterResult result;
@property(readonly, nonatomic) CMMotionManager *motionManager;
@property(readonly, nonatomic) AVCaptureDevicePosition cameraPosition;

- initWithPath:(NSString *)filename
		result:(FlutterResult)result
 motionManager:(CMMotionManager *)motionManager
cameraPosition:(AVCaptureDevicePosition)cameraPosition;
@end

@implementation FLTSavePhotoDelegate {
	/// Used to keep the delegate alive until didFinishProcessingPhotoSampleBuffer.
	FLTSavePhotoDelegate *selfReference;
}

- initWithPath:(NSString *)path
		result:(FlutterResult)result
 motionManager:(CMMotionManager *)motionManager
cameraPosition:(AVCaptureDevicePosition)cameraPosition {
	self = [super init];
	NSAssert(self, @"super init cannot be nil");
	_path = path;
	_result = result;
	_motionManager = motionManager;
	_cameraPosition = cameraPosition;
	selfReference = self;
	return self;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output
didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer
previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer
	 resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
	  bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings
				error:(NSError *)error {
	selfReference = nil;
	if (error) {
		_result(getFlutterError(error));
		return;
	}
	NSData *data = [AVCapturePhotoOutput
					JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer
					previewPhotoSampleBuffer:previewPhotoSampleBuffer];
	UIImage *image = [UIImage imageWithCGImage:[UIImage imageWithData:data].CGImage
										 scale:1.0
								   orientation:[self getImageRotation]];
	// TODO(sigurdm): Consider writing file asynchronously.
	bool success = [UIImageJPEGRepresentation(image, 1.0) writeToFile:_path atomically:YES];
	if (!success) {
		_result([FlutterError errorWithCode:@"IOError" message:@"Unable to write file" details:nil]);
		return;
	}
	_result(nil);
}

- (UIImageOrientation)getImageRotation {
	float const threshold = 45.0;
	BOOL (^isNearValue)(float value1, float value2) = ^BOOL(float value1, float value2) {
		return fabsf(value1 - value2) < threshold;
	};
	BOOL (^isNearValueABS)(float value1, float value2) = ^BOOL(float value1, float value2) {
		return isNearValue(fabsf(value1), fabsf(value2));
	};
	float yxAtan = (atan2(_motionManager.accelerometerData.acceleration.y,
						  _motionManager.accelerometerData.acceleration.x)) *
	180 / M_PI;
	if (isNearValue(-90.0, yxAtan)) {
		return UIImageOrientationRight;
	} else if (isNearValueABS(180.0, yxAtan)) {
		return _cameraPosition == AVCaptureDevicePositionBack ? UIImageOrientationUp
		: UIImageOrientationDown;
	} else if (isNearValueABS(0.0, yxAtan)) {
		return _cameraPosition == AVCaptureDevicePositionBack ? UIImageOrientationDown /*rotate 180* */
		: UIImageOrientationUp /*do not rotate*/;
	} else if (isNearValue(90.0, yxAtan)) {
		return UIImageOrientationLeft;
	}
	// If none of the above, then the device is likely facing straight down or straight up -- just
	// pick something arbitrary
	// TODO: Maybe use the UIInterfaceOrientation if in these scenarios
	return UIImageOrientationUp;
}
@end

// Mirrors ResolutionPreset in camera.dart
typedef enum {
	veryLow,
	low,
	medium,
	high,
	veryHigh,
	ultraHigh,
	max,
} ResolutionPreset;

static ResolutionPreset getResolutionPresetForString(NSString *preset) {
	if ([preset isEqualToString:@"veryLow"]) {
		return veryLow;
	} else if ([preset isEqualToString:@"low"]) {
		return low;
	} else if ([preset isEqualToString:@"medium"]) {
		return medium;
	} else if ([preset isEqualToString:@"high"]) {
		return high;
	} else if ([preset isEqualToString:@"veryHigh"]) {
		return veryHigh;
	} else if ([preset isEqualToString:@"ultraHigh"]) {
		return ultraHigh;
	} else if ([preset isEqualToString:@"max"]) {
		return max;
	} else {
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
											 code:NSURLErrorUnknown
										 userInfo:@{
											 NSLocalizedDescriptionKey : [NSString
																		  stringWithFormat:@"Unknown resolution preset %@", preset]
										 }];
		@throw error;
	}
}

@interface FLTCam : NSObject <FlutterTexture,
AVCaptureVideoDataOutputSampleBufferDelegate,
AVCaptureAudioDataOutputSampleBufferDelegate>
@property(readonly, nonatomic) int64_t textureId;
@property(nonatomic, copy) void (^onFrameAvailable)();
@property BOOL enableAudio;
@property(nonatomic) FlutterEventSink eventSink;
@property(readonly, nonatomic) AVCaptureSession *captureSession;
@property(readonly, nonatomic) AVCaptureDevice *captureDevice;
@property(readonly, nonatomic) AVCapturePhotoOutput *capturePhotoOutput;
@property(readonly, nonatomic) AVCaptureVideoDataOutput *captureVideoOutput;
@property(readonly, nonatomic) AVCaptureInput *captureVideoInput;
@property(readonly) CVPixelBufferRef volatile latestPixelBuffer;
@property(readonly, nonatomic) CGSize previewSize;
@property(strong, nonatomic) AVAssetWriter *videoWriter;
@property(strong, nonatomic) AVAssetWriterInput *videoWriterInput;
@property(strong, nonatomic) AVAssetWriterInput *audioWriterInput;
@property(strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferAdaptor;
@property(strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;
@property(strong, nonatomic) AVCaptureAudioDataOutput *audioOutput;
@property(assign, nonatomic) BOOL isRecording;
@property(assign, nonatomic) BOOL isRecordingPaused;
@property(assign, nonatomic) BOOL videoIsDisconnected;
@property(assign, nonatomic) BOOL audioIsDisconnected;
@property(assign, nonatomic) BOOL isAudioSetup;
@property(assign, nonatomic) ResolutionPreset resolutionPreset;
@property(assign, nonatomic) CMTime lastVideoSampleTime;
@property(assign, nonatomic) CMTime lastAudioSampleTime;
@property(assign, nonatomic) CMTime videoTimeOffset;
@property(assign, nonatomic) CMTime audioTimeOffset;
@property(nonatomic) CMMotionManager *motionManager;
@property AVAssetWriterInputPixelBufferAdaptor *videoAdaptor;
- (instancetype)initWithCameraName:(NSString *)cameraName
				  resolutionPreset:(NSString *)resolutionPreset
					   enableAudio:(BOOL)enableAudio
					 dispatchQueue:(dispatch_queue_t)dispatchQueue
							 error:(NSError **)error;

- (void)start;
- (void)stop;
- (void)startVideoRecordingAtPath:(NSString *)path result:(FlutterResult)result;
- (void)stopVideoRecordingWithResult:(FlutterResult)result;
- (void)captureToFile:(NSString *)filename result:(FlutterResult)result;
@end

@implementation FLTCam {
	dispatch_queue_t _dispatchQueue;
}
// Format used for video and image streaming.
FourCharCode const videoFormat = kCVPixelFormatType_32BGRA;

- (instancetype)initWithCameraName:(NSString *)cameraName
				  resolutionPreset:(NSString *)resolutionPreset
					   enableAudio:(BOOL)enableAudio
					 dispatchQueue:(dispatch_queue_t)dispatchQueue
							 error:(NSError **)error {
	self = [super init];
	NSAssert(self, @"super init cannot be nil");
	@try {
		_resolutionPreset = getResolutionPresetForString(resolutionPreset);
	} @catch (NSError *e) {
		*error = e;
	}
	_enableAudio = enableAudio;
	_dispatchQueue = dispatchQueue;
	_captureSession = [[AVCaptureSession alloc] init];
	
	_captureDevice = [AVCaptureDevice deviceWithUniqueID:cameraName];
	NSError *localError = nil;
	_captureVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice
															   error:&localError];
	if (localError) {
		*error = localError;
		return nil;
	}
	
	_captureVideoOutput = [AVCaptureVideoDataOutput new];
	_captureVideoOutput.videoSettings =
	@{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(videoFormat)};
	[_captureVideoOutput setAlwaysDiscardsLateVideoFrames:YES];
	[_captureVideoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
	
	AVCaptureConnection *connection =
	[AVCaptureConnection connectionWithInputPorts:_captureVideoInput.ports
										   output:_captureVideoOutput];
	if ([_captureDevice position] == AVCaptureDevicePositionFront) {
		connection.videoMirrored = YES;
	}
	connection.videoOrientation = AVCaptureVideoOrientationPortrait;
	[_captureSession addInputWithNoConnections:_captureVideoInput];
	[_captureSession addOutputWithNoConnections:_captureVideoOutput];
	[_captureSession addConnection:connection];
	_capturePhotoOutput = [AVCapturePhotoOutput new];
	[_capturePhotoOutput setHighResolutionCaptureEnabled:YES];
	[_captureSession addOutput:_capturePhotoOutput];
	_motionManager = [[CMMotionManager alloc] init];
	[_motionManager startAccelerometerUpdates];
	
	[self setCaptureSessionPreset:_resolutionPreset];
	return self;
}

- (void)start {
	[_captureSession startRunning];
}

- (void)stop {
	[_captureSession stopRunning];
}

- (void)captureToFile:(NSString *)path result:(FlutterResult)result {
	AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
	if (_resolutionPreset == max) {
		[settings setHighResolutionPhotoEnabled:YES];
	}
	
	[_capturePhotoOutput
	 capturePhotoWithSettings:settings
	 delegate:[[FLTSavePhotoDelegate alloc] initWithPath:path
												  result:result
										   motionManager:_motionManager
										  cameraPosition:_captureDevice.position]];
}

- (void)setCaptureSessionPreset:(ResolutionPreset)resolutionPreset {
	switch (resolutionPreset) {
		case max:
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
				_captureSession.sessionPreset = AVCaptureSessionPresetHigh;
				_previewSize =
				CGSizeMake(_captureDevice.activeFormat.highResolutionStillImageDimensions.width,
						   _captureDevice.activeFormat.highResolutionStillImageDimensions.height);
				break;
			}
		case ultraHigh:
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {
				_captureSession.sessionPreset = AVCaptureSessionPreset3840x2160;
				_previewSize = CGSizeMake(3840, 2160);
				break;
			}
		case veryHigh:
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
				_captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
				_previewSize = CGSizeMake(1920, 1080);
				break;
			}
		case high:
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
				_captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
				_previewSize = CGSizeMake(1280, 720);
				break;
			}
		case medium:
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
				_captureSession.sessionPreset = AVCaptureSessionPresetiFrame960x540;
				_previewSize = CGSizeMake(960, 540);
				break;
			}
			
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
				_captureSession.sessionPreset = AVCaptureSessionPreset640x480;
				_previewSize = CGSizeMake(640, 480);
				break;
			}
		case low:
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset352x288]) {
				_captureSession.sessionPreset = AVCaptureSessionPreset352x288;
				_previewSize = CGSizeMake(352, 288);
				break;
			}
		default:
			if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetLow]) {
				_captureSession.sessionPreset = AVCaptureSessionPresetLow;
				_previewSize = CGSizeMake(352, 288);
			} else {
				NSError *error =
				[NSError errorWithDomain:NSCocoaErrorDomain
									code:NSURLErrorUnknown
								userInfo:@{
									NSLocalizedDescriptionKey :
										@"No capture session available for current capture session."
								}];
				@throw error;
			}
	}
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	   fromConnection:(AVCaptureConnection *)connection {
	if (output == _captureVideoOutput) {
		CVPixelBufferRef newBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
		CFRetain(newBuffer);
		CVPixelBufferRef old = _latestPixelBuffer;
		while (!OSAtomicCompareAndSwapPtrBarrier(old, newBuffer, (void **)&_latestPixelBuffer)) {
			old = _latestPixelBuffer;
		}
		if (old != nil) {
			CFRelease(old);
		}
		if (_onFrameAvailable) {
			_onFrameAvailable();
		}
	}
	if (!CMSampleBufferDataIsReady(sampleBuffer)) {
		_eventSink(@{
			@"event" : @"error",
			@"errorDescription" : @"sample buffer is not ready. Skipping sample"
		});
		return;
	}
	
	if (_isRecording && !_isRecordingPaused) {
		if (_videoWriter.status == AVAssetWriterStatusFailed) {
			_eventSink(@{
				@"event" : @"error",
				@"errorDescription" : [NSString stringWithFormat:@"%@", _videoWriter.error]
			});
			return;
		}
		
		CFRetain(sampleBuffer);
		CMTime currentSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
		
		if (_videoWriter.status != AVAssetWriterStatusWriting) {
			[_videoWriter startWriting];
			[_videoWriter startSessionAtSourceTime:currentSampleTime];
		}
		
		if (output == _captureVideoOutput) {
			if (_videoIsDisconnected) {
				_videoIsDisconnected = NO;
				
				if (_videoTimeOffset.value == 0) {
					_videoTimeOffset = CMTimeSubtract(currentSampleTime, _lastVideoSampleTime);
				} else {
					CMTime offset = CMTimeSubtract(currentSampleTime, _lastVideoSampleTime);
					_videoTimeOffset = CMTimeAdd(_videoTimeOffset, offset);
				}
				
				return;
			}
			
			_lastVideoSampleTime = currentSampleTime;
			
			CVPixelBufferRef nextBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
			CMTime nextSampleTime = CMTimeSubtract(_lastVideoSampleTime, _videoTimeOffset);
			[_videoAdaptor appendPixelBuffer:nextBuffer withPresentationTime:nextSampleTime];
		} else {
			CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
			
			if (dur.value > 0) {
				currentSampleTime = CMTimeAdd(currentSampleTime, dur);
			}
			
			if (_audioIsDisconnected) {
				_audioIsDisconnected = NO;
				
				if (_audioTimeOffset.value == 0) {
					_audioTimeOffset = CMTimeSubtract(currentSampleTime, _lastAudioSampleTime);
				} else {
					CMTime offset = CMTimeSubtract(currentSampleTime, _lastAudioSampleTime);
					_audioTimeOffset = CMTimeAdd(_audioTimeOffset, offset);
				}
				
				return;
			}
			
			_lastAudioSampleTime = currentSampleTime;
			
			if (_audioTimeOffset.value != 0) {
				CFRelease(sampleBuffer);
				sampleBuffer = [self adjustTime:sampleBuffer by:_audioTimeOffset];
			}
			
			[self newAudioSample:sampleBuffer];
		}
		
		CFRelease(sampleBuffer);
	}
}

- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef)sample by:(CMTime)offset {
	CMItemCount count;
	CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
	CMSampleTimingInfo *pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
	CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
	for (CMItemCount i = 0; i < count; i++) {
		pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
		pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
	}
	CMSampleBufferRef sout;
	CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
	free(pInfo);
	return sout;
}

- (void)newVideoSample:(CMSampleBufferRef)sampleBuffer {
	if (_videoWriter.status != AVAssetWriterStatusWriting) {
		if (_videoWriter.status == AVAssetWriterStatusFailed) {
			_eventSink(@{
				@"event" : @"error",
				@"errorDescription" : [NSString stringWithFormat:@"%@", _videoWriter.error]
			});
		}
		return;
	}
	if (_videoWriterInput.readyForMoreMediaData) {
		if (![_videoWriterInput appendSampleBuffer:sampleBuffer]) {
			_eventSink(@{
				@"event" : @"error",
				@"errorDescription" :
					[NSString stringWithFormat:@"%@", @"Unable to write to video input"]
			});
		}
	}
}

- (void)newAudioSample:(CMSampleBufferRef)sampleBuffer {
	if (_videoWriter.status != AVAssetWriterStatusWriting) {
		if (_videoWriter.status == AVAssetWriterStatusFailed) {
			_eventSink(@{
				@"event" : @"error",
				@"errorDescription" : [NSString stringWithFormat:@"%@", _videoWriter.error]
			});
		}
		return;
	}
	if (_audioWriterInput.readyForMoreMediaData) {
		if (![_audioWriterInput appendSampleBuffer:sampleBuffer]) {
			_eventSink(@{
				@"event" : @"error",
				@"errorDescription" :
					[NSString stringWithFormat:@"%@", @"Unable to write to audio input"]
			});
		}
	}
}

- (void)close {
	[_captureSession stopRunning];
	for (AVCaptureInput *input in [_captureSession inputs]) {
		[_captureSession removeInput:input];
	}
	for (AVCaptureOutput *output in [_captureSession outputs]) {
		[_captureSession removeOutput:output];
	}
}

- (void)dealloc {
	if (_latestPixelBuffer) {
		CFRelease(_latestPixelBuffer);
	}
	[_motionManager stopAccelerometerUpdates];
}

- (CVPixelBufferRef)copyPixelBuffer {
	CVPixelBufferRef pixelBuffer = _latestPixelBuffer;
	while (!OSAtomicCompareAndSwapPtrBarrier(pixelBuffer, nil, (void **)&_latestPixelBuffer)) {
		pixelBuffer = _latestPixelBuffer;
	}
	
	return pixelBuffer;
}

- (void)startVideoRecordingAtPath:(NSString *)path result:(FlutterResult)result {
	if (!_isRecording) {
		if (![self setupWriterForPath:path result:result]) {
			result(@"Setup Writer Failed");
			return;
		}
		_isRecording = YES;
		_isRecordingPaused = NO;
		_videoTimeOffset = CMTimeMake(0, 1);
		_audioTimeOffset = CMTimeMake(0, 1);
		_videoIsDisconnected = NO;
		_audioIsDisconnected = NO;
		result(@"ok");
	} else {
		result(@"Video is already recording");
	}
}

- (void)stopVideoRecordingWithResult:(FlutterResult)result {
	if (_isRecording) {
		_isRecording = NO;
		if (_videoWriter.status != AVAssetWriterStatusUnknown) {
			[_videoWriter finishWritingWithCompletionHandler:^{
				if (self->_videoWriter.status == AVAssetWriterStatusCompleted) {
					result(@"ok");
				} else {
					result(@"AVAssetWriter could not finish writing");
				}
			}];
		}
	} else {
		result(@"Video is not recording");
	}
}

- (BOOL)setupWriterForPath:(NSString *)path result:(FlutterResult)result {
	NSError *error = nil;
	NSURL *outputURL;
	if (path != nil) {
		outputURL = [NSURL fileURLWithPath:path];
	} else {
		return NO;
	}
	if (_enableAudio && !_isAudioSetup) {
		[self setUpCaptureSessionForAudio:result];
	}
	_videoWriter = [[AVAssetWriter alloc] initWithURL:outputURL
											 fileType:AVFileTypeQuickTimeMovie
												error:&error];
	NSParameterAssert(_videoWriter);
	if (error) {
		NSLog(@"%@", @{@"event" : @"error", @"errorDescription" : error.description});
		return NO;
	}
	
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(1024 * 1280),
                                             AVVideoExpectedSourceFrameRateKey : @(30),
                                             AVVideoMaxKeyFrameIntervalKey : @(30),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };

	
	NSDictionary *videoSettings = [NSDictionary
								   dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
								   [NSNumber numberWithInt:_previewSize.height], AVVideoWidthKey,
								   [NSNumber numberWithInt:_previewSize.width], AVVideoHeightKey,
								   compressionProperties, AVVideoCompressionPropertiesKey,
								   nil];
	_videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
														   outputSettings:videoSettings];
	
	_videoAdaptor = [AVAssetWriterInputPixelBufferAdaptor
					 assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput
					 sourcePixelBufferAttributes:@{
						 (NSString *)kCVPixelBufferPixelFormatTypeKey : @(videoFormat)
					 }];
	
	NSParameterAssert(_videoWriterInput);
	_videoWriterInput.expectsMediaDataInRealTime = YES;
	
	// Add the audio input
	if (_enableAudio) {
		AudioChannelLayout acl;
		bzero(&acl, sizeof(acl));
		acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
		NSDictionary *audioOutputSettings = nil;
		// Both type of audio inputs causes output video file to be corrupted.
		audioOutputSettings = [NSDictionary
							   dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
							   [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
							   [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
							   [NSData dataWithBytes:&acl length:sizeof(acl)],
							   AVChannelLayoutKey, nil];
		_audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
															   outputSettings:audioOutputSettings];
		_audioWriterInput.expectsMediaDataInRealTime = YES;
		
		[_videoWriter addInput:_audioWriterInput];
		[_audioOutput setSampleBufferDelegate:self queue:_dispatchQueue];
	}
	
	[_videoWriter addInput:_videoWriterInput];
	[_captureVideoOutput setSampleBufferDelegate:self queue:_dispatchQueue];
	
	return YES;
}
- (void)setUpCaptureSessionForAudio:(FlutterResult)result {
	NSError *error = nil;
	// Create a device input with the device and add it to the session.
	// Setup the audio input.
	AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
	AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice
																			 error:&error];
	if (error) {
		result(error.description);
	}
	// Setup the audio output.
	_audioOutput = [[AVCaptureAudioDataOutput alloc] init];
	
	if ([_captureSession canAddInput:audioInput]) {
		[_captureSession addInput:audioInput];
		
		if ([_captureSession canAddOutput:_audioOutput]) {
			[_captureSession addOutput:_audioOutput];
			_isAudioSetup = YES;
		} else {
			result(@"Unable to add Audio input/output to session capture");
			_isAudioSetup = NO;
		}
	}
	
	result(@"ok");
}
@end


@interface EeCameraPlugin ()
@property(readonly, nonatomic) NSObject<FlutterTextureRegistry> *registry;
@property(readonly, nonatomic) NSObject<FlutterBinaryMessenger> *messenger;
@property(readonly, nonatomic) FLTCam *camera;
@property(nonatomic) NSMutableDictionary *deviceTypes;
@end

@implementation EeCameraPlugin{
	dispatch_queue_t _dispatchQueue;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
	FlutterMethodChannel* channel = [FlutterMethodChannel
									 methodChannelWithName:@"ee_camera"
									 binaryMessenger:[registrar messenger]];
	
	EeCameraPlugin* instance = [[EeCameraPlugin alloc] initWithRegistry:[registrar textures]
															  messenger:[registrar messenger]];
	
	[registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry> *)registry
					   messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
	self = [super init];
	NSAssert(self, @"super init cannot be nil");
	_registry = registry;
	_messenger = messenger;
	return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
	
	if (_dispatchQueue == nil) {
		_dispatchQueue = dispatch_queue_create("com.microemp.eecamera.dispatchqueue", NULL);
	}
	
	dispatch_async(_dispatchQueue, ^{
		[self handleMethodCallAsync:call result:result];
	});
}

-(void)getDevice{
	AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
														 discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera ]
														 mediaType:AVMediaTypeVideo
														 position:AVCaptureDevicePositionUnspecified];
	
	NSArray<AVCaptureDevice *> *devices = discoverySession.devices;
	
	self.deviceTypes = [NSMutableDictionary new];
	
	for (AVCaptureDevice *device in devices) {
		NSString *lensFacing;
		switch ([device position]) {
			case AVCaptureDevicePositionBack:
				lensFacing = @"back";
				self.deviceTypes[@"back"] = [device uniqueID];
				break;
			case AVCaptureDevicePositionFront:
				lensFacing = @"front";
				self.deviceTypes[@"front"] = [device uniqueID];
				break;
		}
	}
	
	//NSLog(@"%@", self.deviceTypes);
}


- (void)handleMethodCallAsync:(FlutterMethodCall *)call result:(FlutterResult)result {
	
	if ([@"initialize" isEqualToString:call.method]) {
		[self getDevice];
		NSString *resolutionPreset = call.arguments[@"resolution"];
		NSString *cameraType = call.arguments[@"type"];
		Boolean enableAudio = [call.arguments[@"enableAudio"] boolValue];

		// 提前申请麦克风权限
		if (enableAudio){
			AVAudioSession* sharedSession = [AVAudioSession sharedInstance];
			[sharedSession requestRecordPermission:^(BOOL granted) {
				NSLog(@"%@ -- %@", @(granted), @([NSThread isMainThread]));
				dispatch_sync(dispatch_get_main_queue(), ^{

				});
			}];
		}
		
		NSError *error;
		FLTCam *cam = [[FLTCam alloc] initWithCameraName:self.deviceTypes[cameraType]
										resolutionPreset:resolutionPreset
											 enableAudio:enableAudio
										   dispatchQueue:_dispatchQueue
												   error:&error];
		if (error) {
			result(getFlutterError(error));
			NSLog(@"fuck error, %@",  (error));
		} else {
			if (_camera) {
				[_camera close];
			}
			int64_t textureId = [_registry registerTexture:cam];
			_camera = cam;
			cam.onFrameAvailable = ^{
				[_registry textureFrameAvailable:textureId];
			};
			
			result(@{
				@"textureId" : @(textureId),
				@"width" : @(cam.previewSize.width),
				@"height" : @(cam.previewSize.height),
				@"status" : @"ok",
				@"api" : @"ios",
			});
			
			[cam start];
		}
	} else {
		NSDictionary *argsMap = call.arguments;

		if ([@"test" isEqualToString:call.method]) {
			result(@"ok");
		}else if ([@"takePhoto" isEqualToString:call.method]) {
			[_camera captureToFile:call.arguments[@"path"] result:result];
		} else if ([@"dispose" isEqualToString:call.method]) {
			NSUInteger textureId = ((NSNumber *)argsMap[@"textureId"]).unsignedIntegerValue;
			[_registry unregisterTexture:textureId];
			[_camera close];
			_dispatchQueue = nil;
			result(@"ok");
		} else if ([@"prepareRecord" isEqualToString:call.method]) {
			[_camera setUpCaptureSessionForAudio:result];
			result(@"ok");
		} else if ([@"startRecord" isEqualToString:call.method]) {
			[_camera startVideoRecordingAtPath:call.arguments[@"path"] result:result];
		} else if ([@"stopRecord" isEqualToString:call.method]) {
			[_camera stopVideoRecordingWithResult:result];
		} else {
			result(FlutterMethodNotImplemented);
		}
	}
}

@end
