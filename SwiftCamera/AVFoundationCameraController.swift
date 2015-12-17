/*
File:  CameraController.swift

Copyright © 2015 Giancarlo Daniele. All rights reserved.
*/

import AVFoundation
import Photos
import UIKit

// TODO:
// ------
// * Support output mode (still img vs video)
// 
//

// MARK:- Useful Extensions

/*!
@extension AVCaptureVideoOrientation
@abstract
AVCaptureVideoOrientation is an enum representing the desired orientation of an AVFoundation capture.

@discussion
`fromUIInterfaceOrientation()` allows easy conversion from the enum representing the current iOS device's UI and the enum representing AVFoundation orientation possibilities.
*/
extension AVCaptureVideoOrientation {
	static func fromUIInterfaceOrientation(orientation: UIInterfaceOrientation) throws -> AVCaptureVideoOrientation {
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
An AVFoundationCameraController is a CameraController that uses AVFoundation to manage an iOS camera session according to set up details.

@discussion
An AVFoundationCameraController uses the AVFoundation framework to manage a camera session in iOS 9+.
*/
public class AVFoundationCameraController: NSObject, CameraController {
	// Session management
	private let movieFileOutput: AVCaptureMovieFileOutput? = nil
	private var previewLayer: AVCaptureVideoPreviewLayer? = nil
	private weak var previewView: UIView? = nil
	private let session: AVCaptureSession
	private let sessionQueue: dispatch_queue_t
	private var stillImageOutput: AVCaptureStillImageOutput? = nil
	private var videoDeviceInput: AVCaptureDeviceInput? = nil
	
	// State
	private let captureFlashMode: AVCaptureFlashMode = .Off
	private var observers = WeakSet<CameraControllerObserver>()
	
	// Utilities
	private var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
	private var sessionRunning: Bool = false

	override init() {
		// Create session
		self.session = AVCaptureSession()
		self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL)
		
		super.init()
	}
	
	// MARK:- Public Properties
	
	public var flashMode: AVCaptureFlashMode {
		get {
			return self.captureFlashMode
		}
		set {
			guard flashMode != self.captureFlashMode else {
				return
			}
			self.updateFlashMode(flashMode)
		}
	}
	
	private(set) public var setupResult: CameraControllerSetupResult = .Success
	
	// MARK:- Public Class API
	
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
	
	public func connectCameraToView(previewView: UIView, error: ((ErrorType) -> ())?) {
		guard self.deviceSupportsCamera() else {
			self.setupResult = .ConfigurationFailed
			error?(CameraControllerVideoDeviceError.NotFound)
			return
		}
		
		if let uPreviewLayer = self.previewLayer {
			uPreviewLayer.removeFromSuperlayer()
		}
		
		if self.setupResult == .Running {
			self.addPreviewLayerToView(previewView, error: error)
		} else {
			self.startCaptureWithSuccess({ () -> () in
				self.addPreviewLayerToView(previewView, error: error)
			}, error: error)
		}
	}
	
	public func startVideoRecording() {
		
	}
	
	public func stopVideoRecording() {
		
	}
	
	public func takePhoto() {
		
	}
	
	// MARK:- Private API
	
	// Adds session to preview layer
	private func addPreviewLayerToView(previewView: UIView, error: ((ErrorType) -> ())?) {
		self.previewView = previewView
		dispatch_async(dispatch_get_main_queue()) { () -> Void in
			if let uPreviewLayer = self.previewLayer {
				uPreviewLayer.frame = previewView.layer.bounds
				previewView.clipsToBounds = true
				previewView.layer.addSublayer(uPreviewLayer)
			}
		}
	}
	
	// Checks video authorization status and updates `setupResult`. Note: audio authorization will be requested automatically when an AVCaptureDeviceInput is created.
	private func checkAuthorizationStatus(error: ((ErrorType) -> ())?) {
		switch AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) {
		case .NotDetermined:
			self.requestAccess(error)
		case .Denied:
			self.setupResult = .NotAuthorized
			error?(CameraControllerVideoDeviceError.NotAuthorized)
			print("Permission denied")
		case .Restricted:
			self.setupResult = .ConfigurationFailed
			error?(CameraControllerVideoDeviceError.SetupFailed)
			print("Access to the media device is restricted")
		default: break
		}
	}
	
	private func deviceSupportsCamera() -> Bool {
		guard UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front) else {
			print("Hardware not supported")
			return false
		}
		return true
	}
	
	// Gives user the option to grant video access. Suspends the session queue to avoid asking the user for audio access (via session queue initialization) if video access has not yet been granted.
	private func requestAccess(error: ((ErrorType) -> ())?) {
		dispatch_suspend(self.sessionQueue)
		
		AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
			dispatch_resume(self.sessionQueue)

			guard granted else {
				self.setupResult = .NotAuthorized
				error?(CameraControllerVideoDeviceError.NotAuthorized)
				return
			}
		})
	}
	
	// Sets up the capture session. Note: AVCaptureSession.startRunning is synchronous and might take a while to execute. For this reason, we start the session on the coordinated shared `sessionQueue` (and use that queue to access the camera in any further actions)
	private func setCaptureSessionWithSuccess(success: (()->())?, error: ((CameraControllerVideoDeviceError) -> ())?) {
		dispatch_async(self.sessionQueue, { () in
			guard self.setupResult == .Success else {
				error?(CameraControllerVideoDeviceError.NotAuthorized)
				return
			}
			
			self.backgroundRecordingID = UIBackgroundTaskInvalid
			
			guard let videoDevice = try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, preferredPosition: AVCaptureDevicePosition.Back), let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
				print("Could not get video device")
				error?(CameraControllerVideoDeviceError.SetupFailed)
				return
			}
			
			self.session.beginConfiguration()
			self.session.sessionPreset = AVCaptureSessionPresetHigh
			
			guard self.session.canAddInput(videoDeviceInput) else {
				error?(CameraControllerVideoDeviceError.SetupFailed)
				print("Could not add video device input to the session")
				return
			}
			
			self.session.addInput(videoDeviceInput)
			self.videoDeviceInput = videoDeviceInput
			
			self.setPreviewLayerOrientation { previewError in
				error?(CameraControllerVideoDeviceError.SetupFailed)
				return
			}
			
			// Set preview layer
			self.setPreviewLayer()
			
			// Set stillImageOutput
			let stillImageOutput = AVCaptureStillImageOutput()
			
			if self.session.canAddOutput(stillImageOutput) {
				stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
				self.session.addOutput(stillImageOutput)
				self.stillImageOutput = stillImageOutput
			}
			
			self.session.commitConfiguration()
			
			success?()
		})
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
			
			guard let newOrientation = try? AVCaptureVideoOrientation.fromUIInterfaceOrientation(currentStatusBarOrientation) else {
				uPreviewLayer.connection.videoOrientation = .Portrait
				return
			}
			uPreviewLayer.connection.videoOrientation = newOrientation
		})
	}
	
	private func startCaptureWithSuccess(success: (()->())?, error: ((ErrorType)->())?) {
		// Check authorization status and requests camera permissions if necessary
		self.checkAuthorizationStatus(nil)
		
		// Set up the capture session
		self.setCaptureSessionWithSuccess({
			dispatch_async(self.sessionQueue, {
				self.session.startRunning()
				self.setupResult = .Running
			})
			success?()
		}, error: { uError in
			error?(uError)
		})
	}
	
	private func updateFlashMode(flashMode: AVCaptureFlashMode) {
		// TODO: Implement me
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
