/*
File:  CameraController.swift

Copyright © 2015 Giancarlo Daniele. All rights reserved.
*/

import AVFoundation
import Photos
import UIKit

// MARK:- Useful Extensions

/*!
@struct AVCaptureVideoOrientationTransformer
@abstract
AVCaptureVideoOrientation is an enum representing the desired orientation of an AVFoundation capture.

@discussion
`fromUIInterfaceOrientation()` allows easy conversion from the enum representing the current iOS device's UI and the enum representing AVFoundation orientation possibilities.
*/
struct AVCaptureVideoOrientationTransformer {
	static func AVCaptureVideoOrientationTransformerFromUIInterfaceOrientation(orientation: UIInterfaceOrientation) throws -> AVCaptureVideoOrientation {
		switch orientation {
		case .Portrait:
			return .Portrait
		case .PortraitUpsideDown:
			return .PortraitUpsideDown
		case .LandscapeRight:
			return .LandscapeRight
		case .LandscapeLeft:
			return .LandscapeLeft
		default:
			throw AVCaptureVideoOrientationConversionError.NotValid
		}
	}
}

public enum AVCaptureVideoOrientationConversionError: ErrorType {
	case NotValid
}

/*!
@class AVFoundationCameraController
@abstract
An AVFoundationCameraController is a CameraController that uses AVFoundation to manage an iOS camera session accordintakePhotog to set up details.

@discussion
An AVFoundationCameraController uses the AVFoundation framework to manage a camera session in iOS 9+.
*/
public class AVFoundationCameraController: NSObject, CameraController {
	// MARK:-  Session management
	private let movieFileOutput: AVCaptureMovieFileOutput? = nil
	private var previewLayer: AVCaptureVideoPreviewLayer? = nil
	private weak var previewView: UIView? = nil
	private let session: AVCaptureSession
	private let sessionQueue: dispatch_queue_t
	private var stillImageOutput: AVCaptureStillImageOutput? = nil
	private var videoDeviceInput: AVCaptureDeviceInput? = nil
	
	// MARK:-  State
	private var availableCaptureDevicePositions: Set<AVCaptureDevicePosition>?
	private var observers = WeakSet<CameraControllerObserver>()
	private var outputMode: CameraOutputMode = .StillImage
	private var setupResult: CameraControllerSetupResult = .Success
	
	// MARK:-  Utilities
	private var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
	private var sessionRunning: Bool = false
	
	override init() {
		self.availableCaptureDevicePositions = AVFoundationCameraController.availableCaptureDevicePositions(AVMediaTypeVideo)
		self.session = AVCaptureSession()
		self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL)
		
		super.init()
	}
	
	// MARK:- Public Properties
	
	public var authorizationStatus: AVAuthorizationStatus {
		get {
			return AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
		}
	}
	
	public private(set) var cameraPosition: AVCaptureDevicePosition = .Unspecified
	
	public private(set) var captureQuality: CaptureQuality = .High
	
	public private(set) var flashMode: AVCaptureFlashMode = .Off
	
	public var hasFlash: Bool {
		get {
			return self.backCaptureDevice?.hasFlash ?? false
		}
	}
	
	public var hasFrontCamera: Bool {
		get {
			return self.availableCaptureDevicePositions?.contains(.Front) ?? false
		}
	}
	
	public var supportedCameraPositions: Set<AVCaptureDevicePosition> {
		get {
			return AVFoundationCameraController.availableCaptureDevicePositions(AVMediaTypeVideo)
		}
	}
	
	public var supportedFeatures: [CameraSupportedFeature] {
		get {
			var supportedFeatures = [CameraSupportedFeature]()
			if hasFlash { supportedFeatures.append(.Flash) }
			if hasFrontCamera { supportedFeatures.append(.FrontCamera) }
			return supportedFeatures
		}
	}
	
	// MARK:- Public Class API
	
	public class func availableCaptureDevicePositions(mediaType: String) -> Set<AVCaptureDevicePosition> {
		return Set(AVCaptureDevice.devicesWithMediaType(mediaType).map { $0.position })
	}
	
	// Returns an AVCAptureDevice with the given media type. Throws an error if not available.
	public class func deviceWithMediaType(mediaType: String, position: AVCaptureDevicePosition) throws -> AVCaptureDevice {
		// Fallback if device with preferred position not available
		let devices = AVCaptureDevice.devicesWithMediaType(mediaType)
		let preferredDevice = devices.filter { device in
			device.position == position
			}.first
		
		guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice) where preferredDevice is AVCaptureDevice else {
			throw CameraControllerVideoDeviceError.NotFound
		}
		
		return uPreferredDevice
	}
	
	// Returns an AVCAptureDevice with the given media type. Throws an error if not available. Note that if a device with preferredPosition is not available, the first available device is returned.
	public class func deviceWithMediaType(mediaType: String, preferredPosition: AVCaptureDevicePosition) throws -> AVCaptureDevice {
		// Fallback if device with preferred position not available
		let devices = AVCaptureDevice.devicesWithMediaType(mediaType)
		let defaultDevice = devices.first
		let preferredDevice = devices.filter { device in
			device.position == preferredPosition
			}.first
		
		guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice) where preferredDevice is AVCaptureDevice else {
			
			guard let uDefaultDevice = (defaultDevice as? AVCaptureDevice) where defaultDevice is AVCaptureDevice else {
				throw CameraControllerVideoDeviceError.NotFound
			}
			return uDefaultDevice
		}
		
		return uPreferredDevice
	}
	
	// MARK:- Public Instance API
	
	public func connectCameraToView(previewView: UIView, completion: ((Bool, ErrorType?) -> ())?) {
		guard self.deviceSupportsCamera() else {
			self.setupResult = .ConfigurationFailed
			completion?(false, CameraControllerVideoDeviceError.NotFound)
			return
		}
		
		if let uPreviewLayer = self.previewLayer {
			uPreviewLayer.removeFromSuperlayer()
		}
		
		if self.setupResult == .Running {
			self.addPreviewLayerToView(previewView, completion: completion)
		} else {
			self.startCaptureWithSuccess({ success, error in
				guard success && error == nil else {
					completion?(success, error)
					return
				}
				self.addPreviewLayerToView(previewView, completion: completion)
			})
		}
	}
	
	public func setCameraPosition(position: AVCaptureDevicePosition) throws {
		guard position != self.cameraPosition else {
			return
		}
		try self.setPosition(position)
	}
	
	public func setFlashMode(mode: AVCaptureFlashMode) throws {
		guard mode != self.flashMode else {
			return
		}
		
		try self.setFlash(mode)
	}
	
	public func stopCaptureSession() {
		self.session.stopRunning()
	}
	
	public func startCaptureSession() {
		guard !self.session.running else {
			print("Session is already running")
			return
		}
		self.session.startRunning()
	}
	
	public func startVideoRecording() {
		
	}
	
	public func stopVideoRecording() {
		
	}
	
	public func takePhoto(completion: ((UIImage?, ErrorType?)->())?) {
		guard self.setupResult == .Running else {
			completion?(nil, CameraControllerError.NotRunning)
			return
		}
		
		guard let uStillImageOutput = self.stillImageOutput where self.outputMode == .StillImage else {
			completion?(nil, CameraControllerError.WrongConfiguration)
			return
		}
		
		dispatch_async(self.sessionQueue, {
			uStillImageOutput.captureStillImageAsynchronouslyFromConnection(uStillImageOutput.connectionWithMediaType(AVMediaTypeVideo),
				completionHandler: { imageDataSampleBuffer, receivedError in
					guard receivedError == nil else {
						completion?(nil, receivedError!)
						return
					}
					if let uImageDataBuffer = imageDataSampleBuffer {
						let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(uImageDataBuffer)
						guard let image = UIImage(data: imageData) else {
							completion?(nil, CameraControllerError.ImageCaptureFailed)
							return
						}
						dispatch_async(dispatch_get_main_queue(), {
							completion?(image, nil)
							return
						})
					}
			})
		})
	}
	
	// MARK:- Private lazy vars
	
	private lazy var backCaptureDevice: AVCaptureDevice? = {
		return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .Back)
	}()
	
	private lazy var frontCaptureDevice: AVCaptureDevice? = {
		return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .Front)
	}()
	
	// MARK:- Private API
	
	// Adds session to preview layer
	private func addPreviewLayerToView(previewView: UIView, completion: ((Bool, ErrorType?) -> ())?) {
		self.previewView = previewView
		dispatch_async(dispatch_get_main_queue()) { () -> Void in
			guard let uPreviewLayer = self.previewLayer else {
				completion?(false, CameraControllerPreviewLayerError.NotFound)
				return
			}
			uPreviewLayer.frame = previewView.layer.bounds
			previewView.clipsToBounds = true
			previewView.layer.insertSublayer(uPreviewLayer, atIndex: 0)
			completion?(true, nil)
			return
		}
	}
	
	// Checks video authorization status and updates `setupResult`. Note: audio authorization will be requested automatically when an AVCaptureDeviceInput is created.
	private func checkAuthorizationStatus(completion: ((Bool, ErrorType?) -> ())?) {
		switch AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) {
		case .NotDetermined:
			self.requestAccess(completion)
		case .Denied:
			self.setupResult = .NotAuthorized
			completion?(false, CameraControllerVideoDeviceError.NotAuthorized)
			print("Permission denied")
		case .Restricted:
			self.setupResult = .ConfigurationFailed
			completion?(false, CameraControllerVideoDeviceError.SetupFailed)
			print("Access to the media device is restricted")
			return
		default:
			completion?(true, nil)
			return
		}
	}
	
	private func deviceSupportsCamera() -> Bool {
		guard UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front) else {
			print("Hardware not supported")
			return false
		}
		return true
	}
	
	private func getDevice(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
		switch position {
		case .Front:
			return self.frontCaptureDevice
		case .Back:
			return self.backCaptureDevice
		default: return nil
		}
	}
	
	// Gives user the option to grant video access. Suspends the session queue to avoid asking the user for audio access (via session queue initialization) if video access has not yet been granted.
	private func requestAccess(completion: ((Bool, ErrorType?) -> ())?) {
		dispatch_suspend(self.sessionQueue)
		
		AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
			dispatch_resume(self.sessionQueue)
			
			guard granted else {
				self.setupResult = .NotAuthorized
				completion?(false, CameraControllerVideoDeviceError.NotAuthorized)
				return
			}
			completion?(true, nil)
			return
		})
	}
	
	private func setCaptureQuality(quality: CaptureQuality) throws {
		guard self.captureQuality != quality else {
			return
		}
	}
	
	// Sets up the capture session. Assumes that authorization status has
	// already been checked.
	// Note: AVCaptureSession.startRunning is synchronous and might take a while to execute. For this reason, we start the session on the coordinated shared `sessionQueue` (and use that queue to access the camera in any further actions)
	private func setCaptureSessionWithCompletion(completion: ((Bool, ErrorType?) -> ())?) {
		dispatch_async(self.sessionQueue, { () in
			guard self.setupResult == .Success else {
				completion?(false, CameraControllerVideoDeviceError.NotAuthorized)
				return
			}
			self.backgroundRecordingID = UIBackgroundTaskInvalid
			
			do {
				try self.setPosition(self.cameraPosition)
			} catch {
				completion?(false, error)
				return
			}
			
			// Set preview layer
			self.setPreviewLayer()
			
			self.setPreviewLayerOrientation { previewError in
				completion?(false, CameraControllerVideoDeviceError.SetupFailed)
				return
			}
			
			try? self.setFlash(self.flashMode)
			
			// Set Still Image Output
			// TODO: In the future, read this info from user config
			let stillImageOutput = AVCaptureStillImageOutput()
			
			if self.session.canAddOutput(stillImageOutput) {
				stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
				self.session.addOutput(stillImageOutput)
				self.stillImageOutput = stillImageOutput
			}
			
			self.session.commitConfiguration()
			
			completion?(true, nil)
		})
	}
	
	private func setFlash(mode: AVCaptureFlashMode) throws {
		self.session.beginConfiguration()
		
		guard let uBackDevice = self.backCaptureDevice where uBackDevice.hasFlash else {
			throw CameraControllerError.DeviceDoesNotSupportFeature
		}
		
		guard uBackDevice.isFlashModeSupported(mode) else {
			throw CameraControllerError.DeviceDoesNotSupportFeature
		}
		
		try uBackDevice.lockForConfiguration()
		uBackDevice.flashMode = mode
		uBackDevice.unlockForConfiguration()
		
		self.flashMode = mode
		self.session.commitConfiguration()
	}
	
	private func setPosition(position: AVCaptureDevicePosition) throws {
		
		switch position {
		case .Unspecified:
			guard let uVideoDevice = try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, preferredPosition: position), let uInput = try? AVCaptureDeviceInput(device: uVideoDevice) else {
				throw CameraControllerVideoDeviceError.SetupFailed
			}
			try self.setInputsForVideoDevice(uVideoDevice, input: uInput)
		default:
			guard let uVideoDevice = self.getDevice(position), let uInput = try? AVCaptureDeviceInput(device: uVideoDevice) where self.supportsCameraPosition(position) else {
				print("Could not get video device")
				throw CameraControllerVideoDeviceError.SetupFailed
			}
			try self.setInputsForVideoDevice(uVideoDevice, input: uInput)
		}
		
		self.cameraPosition = position
	}
	
	private func setInputsForVideoDevice(videoDevice: AVCaptureDevice, input: AVCaptureDeviceInput) throws {
		// add inputs and commit config
		self.session.beginConfiguration()
		
		self.session.sessionPreset = AVCaptureSessionPresetHigh
		
		if let uVideoDeviceInput = self.videoDeviceInput {
			self.session.removeInput(uVideoDeviceInput)
		}
		
		guard self.session.canAddInput(input) else {
			print("Could not add video device input to the session")
			throw CameraControllerVideoDeviceError.SetupFailed
		}
		
		self.session.addInput(input)
		self.videoDeviceInput = input
		
		self.session.commitConfiguration()
	}
	
	private func setPreviewLayer() {
		self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
		self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
	}
	
	private func setPreviewLayerOrientation(error: ((CameraControllerPreviewLayerError) -> ())?) {
		guard let uPreviewLayer = self.previewLayer else {
			error?(CameraControllerPreviewLayerError.NotFound)
			return
		}
		
		dispatch_async(dispatch_get_main_queue(), {
			// We need to dispatch to the main thread here
			// because our preview layer is backed by UIKit
			// which runs on the main thread
			let currentStatusBarOrientation = UIApplication.sharedApplication().statusBarOrientation
			
			guard let uConnection = uPreviewLayer.connection, newOrientation = try? AVCaptureVideoOrientationTransformer.AVCaptureVideoOrientationTransformerFromUIInterfaceOrientation(currentStatusBarOrientation) else {
				return
			}
			uConnection.videoOrientation = .Portrait
			uConnection.videoOrientation = newOrientation
		})
	}
	
	private func startCaptureWithSuccess(completion: ((Bool, ErrorType?)->())?) {
		// Check authorization status and requests camera permissions if necessary
		self.checkAuthorizationStatus({ didSucceed, error in
			guard didSucceed && error == nil else {
				completion?(false, error)
				return
			}
		})
		
		// Set up the capture session
		self.setCaptureSessionWithCompletion({ didSucceed, error in
			guard didSucceed && error == nil else {
				print("Capture error")
				completion?(false, error)
				return
			}
			dispatch_async(self.sessionQueue, {
				self.session.startRunning()
				self.setupResult = .Running
				completion?(true, nil)
				return
			})
		})
	}
	
	private func supportsCameraPosition(postition: AVCaptureDevicePosition) -> Bool {
		guard let uAvailableDevicePositions = self.availableCaptureDevicePositions else {
			self.availableCaptureDevicePositions = AVFoundationCameraController.availableCaptureDevicePositions(AVMediaTypeVideo)
			return self.availableCaptureDevicePositions!.contains(postition)
		}
		return uAvailableDevicePositions.contains(postition)
	}
}

extension AVFoundationCameraController: CameraControllerSubject {
	
	private func notify(propertyName: String, value: AnyObject?) {
		for observer in observers {
			observer.updatePropertyWithName(propertyName, value: value)
		}
	}
	
	public func subscribe(observer: CameraControllerObserver) {
		self.observers.addObject(observer)
	}
	
	public func unsubscribe(observer: CameraControllerObserver) {
		self.observers.removeObject(observer)
	}
}

class WeakSet<ObjectType>: SequenceType {
	
	var count: Int {
		return weakStorage.count
	}
	
	private let weakStorage = NSHashTable.weakObjectsHashTable()
	
	func addObject(object: ObjectType) {
		guard object is AnyObject else { fatalError("Object (\(object)) should be subclass of AnyObject") }
		weakStorage.addObject(object as? AnyObject)
	}
	
	func removeObject(object: ObjectType) {
		guard object is AnyObject else { fatalError("Object (\(object)) should be subclass of AnyObject") }
		weakStorage.removeObject(object as? AnyObject)
	}
	
	func removeAllObjects() {
		weakStorage.removeAllObjects()
	}
	
	func containsObject(object: ObjectType) -> Bool {
		guard object is AnyObject else { fatalError("Object (\(object)) should be subclass of AnyObject") }
		return weakStorage.containsObject(object as? AnyObject)
	}
	
	func generate() -> AnyGenerator<ObjectType> {
		let enumerator = weakStorage.objectEnumerator()
		return anyGenerator {
			return enumerator.nextObject() as! ObjectType?
		}
	}
}
