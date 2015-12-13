/*
File:  CameraController.swift

Copyright © 2015 Giancarlo Daniele. All rights reserved.
*/

import AVFoundation
import Photos
import UIKit

/*!
@error CameraControllerVideoDeviceError
@abstract
`CameraControllerVideoDeviceError` represents CameraController video device error possibilities.

@discussion
Camera controller may fail to function due to a variety of setup and permissions errors represented in this enum.
*/
public enum CameraControllerVideoDeviceError: ErrorType {
	case NotAuthorized
	case NotFound
	case SetupFailed
}

/*!
@extension CameraController
@abstract
CameraController provides an easy-to-use api for managing a hardware camera interface in iOS.

@discussion
`CameraController` provides an interface for setting up and performing common camera functions.
*/
public protocol CameraController {
	// Properties
	var flashMode: AVCaptureFlashMode { get set }
	var setupResult: CameraControllerSetupResult { get }
	
	// Internal API
	func addCameraPreviewToView(previewView: UIView)
	func startVideoRecording()
	func stopVideoRecording()
	func takePhoto()
}

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
			throw ErrorType
		}
	}
}

/*!
@enum CameraControllerSetupResult
@abstract
Constants indicating the result of CameraController set up.

@constant ConfigurationFailed
Indicates that an error occurred and the camera capture configuration failed.
@constant NotAuthorized
Indicates that the user has not authorized camera usage and must do so before using CameraController
@constant Success
Indicates that set up has completed successfully
*/
public enum CameraControllerSetupResult {
	case ConfigurationFailed
	case NotAuthorized
	case Success
	case Restricted
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
	private let session: AVCaptureSession
	private let sessionQueue: dispatch_queue_t
	private let stillImageOutput: AVCaptureStillImageOutput? = nil
	private var videoDeviceInput: AVCaptureDeviceInput? = nil
	
	// State
	private let captureFlashMode: AVCaptureFlashMode = .Off
	
	// Utilities
	private var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
	private var sessionRunning: Bool = false

	init(configurationFailedErrorBlock: ((CameraControllerVideoDeviceError)->())?, notAuthorizedErrorBlock: ((CameraControllerSetupResult)-> ())?) {
		// Create session
		self.session = AVCaptureSession()
		self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL)
		
		super.init()

		// Check authorization status
		self.checkAuthorizationStatus(notAuthorizedErrorBlock)
		
		// Set up the capture session
		self.setCaptureSession { error in
			configurationFailedErrorBlock?(error)
		}
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
	
	public var setupResult: CameraControllerSetupResult = .Success
	
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
	
	public func addCameraPreviewToView(previewView: UIView) {
		guard let capturePreviewLayer = previewView.layer as? AVCaptureVideoPreviewLayer else {
			print("Could not cast previewView layer to AVCaptureVideoPreviewLayer")
			return
		}
		capturePreviewLayer.session = self.session
	}
	
	public func startVideoRecording() {
		
	}
	
	public func stopVideoRecording() {
		
	}
	
	public func takePhoto() {
		
	}
	
	// MARK:- Private API
	
	// Checks video authorization status and updates `setupResult`. Note: audio authorization will be requested automatically when an AVCaptureDeviceInput is created.
	private func checkAuthorizationStatus(notAuthorizedErrorBlock: ((CameraControllerSetupResult)-> ())?) {
		switch AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) {
		case .NotDetermined:
			self.requestAccess(notAuthorizedErrorBlock)
		case .Denied:
			self.setupResult = .NotAuthorized
			notAuthorizedErrorBlock?(.NotAuthorized)
		case .Restricted:
			self.setupResult = .ConfigurationFailed
			notAuthorizedErrorBlock?(.Restricted)
			print("Access to the media device is restricted")
		default: break
		}
	}
	
	// Gives user the option to grant video access. Suspends the session queue to avoid asking the user for audio access (via session queue initialization) if video access has not yet been granted.
	private func requestAccess(notAuthorizedErrorBlock: ((CameraControllerSetupResult)-> ())?) {
		dispatch_suspend(self.sessionQueue)
		
		AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
			dispatch_resume(self.sessionQueue)

			guard granted else {
				notAuthorizedErrorBlock?(.NotAuthorized)
				self.setupResult = .NotAuthorized
				return
			}
		})
	}
	
	// Sets up the capture session. Note: AVCaptureSession.startRunning is synchronous and might take a while to execute. For this reason, we start the session on the coordinated shared `sessionQueue` (and use that queue to access the camera in any further actions)
	private func setCaptureSession(error: ((CameraControllerVideoDeviceError) -> ())?) {
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
			
			guard self.session.canAddInput(videoDeviceInput) else {
				error?(CameraControllerVideoDeviceError.SetupFailed)
				print("Could not add video device input to the session")
				return
			}
			
			self.session.addInput(videoDeviceInput)
			self.videoDeviceInput = videoDeviceInput
			dispatch_async(dispatch_get_main_queue(), {
				// We need to dispatch to the main thread here
				// because our preview layer is backed by UIKit
				// which runs on the main thread
				let currentStatusBarOrientation = UIApplication.sharedApplication().statusBarOrientation
				var initialVideoOrientation = AVCaptureVideoOrientation.Portrait
				
				guard currentStatusBarOrientation != .Unknown else {
					return
				}
				
				initialVideoOrientation = AVCaptureVideoOrientation
				
				
			})
			

		})
	}
	
	private func updateFlashMode(flashMode: AVCaptureFlashMode) {
		// TODO: Implement me
	}
}
