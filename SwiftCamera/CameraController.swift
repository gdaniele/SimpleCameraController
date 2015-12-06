/*
File:  CameraController.swift

Copyright © 2015 Giancarlo Daniele. All rights reserved.
*/

import AVFoundation
import Photos
import UIKit

public enum CameraControllerError: ErrorType {
	case NoVideoDevice
}

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
	private let session: AVCaptureSession
	private let sessionQueue: dispatch_queue_t
	private let stillImageOutput: AVCaptureStillImageOutput? = nil
	
	// State
	private let captureFlashMode: AVCaptureFlashMode = .Off
	
	// Utilities
	private var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
	private var sessionRunning: Bool = false

	init(configurationFailedErrorBlock: (()->())?, notAuthorizedErrorBlock: (()-> ())?) {
		// Create session
		self.session = AVCaptureSession()
		self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL)
		
		super.init()

		// Check authorization status
		self.checkAuthorizationStatus(notAuthorizedErrorBlock)
		
		// Set up the capture session
		self.setCaptureSession()
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
				throw CameraControllerError.NoVideoDevice
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
	private func checkAuthorizationStatus(notAuthorizedErrorBlock: (()-> ())?) {
		switch AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) {
		case .NotDetermined:
			self.requestAccess(notAuthorizedErrorBlock)
		case .Denied:
			self.setupResult = .NotAuthorized
			notAuthorizedErrorBlock?()
		case .Restricted:
			self.setupResult = .ConfigurationFailed
			print("Access to the media device is restricted")
		default: break
		}
	}
	
	// Gives user the option to grant video access. Suspends the session queue to avoid asking the user for audio access (via session queue initialization) if video access has not yet been granted.
	private func requestAccess(notAuthorizedErrorBlock: (()-> ())?) {
		dispatch_suspend(self.sessionQueue)
		
		AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
			dispatch_resume(self.sessionQueue)

			guard granted else {
				notAuthorizedErrorBlock?()
				self.setupResult = .NotAuthorized
				return
			}
		})
	}
	
	// Sets up the capture session. Note: AVCaptureSession.startRunning is synchronous and might take a while to execute. For this reason, we start the session on the coordinated shared `sessionQueue` (and use that queue to access the camera in any further actions)
	private func setCaptureSession() {
		dispatch_async(self.sessionQueue, { () in
			guard self.setupResult == .Success else {
				return
			}
			
			self.backgroundRecordingID = UIBackgroundTaskInvalid

			
		})
	}
	
	private func updateFlashMode(flashMode: AVCaptureFlashMode) {
		// TODO: Implement me
	}
}
