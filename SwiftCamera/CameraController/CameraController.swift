//
//  CameraController.swift
//  SwiftCamera
//
//  Created by Giancarlo on 12/14/15.
//  Copyright © 2015 Giancarlo. All rights reserved.
//

import AVFoundation
import UIKit

/*!
@protocol CameraController
@abstract
CameraController provides an easy-to-use api for managing a hardware camera interface in iOS.

@discussion
`CameraController` provides an interface for setting up and performing common camera functions.
*/
public protocol CameraController: CameraControllerSubject {
	// Properties
	var authorizationStatus: AVAuthorizationStatus { get }
	var cameraPosition: AVCaptureDevicePosition { get }
	var captureQuality: CaptureQuality { get }
	var flashMode: AVCaptureFlashMode { get }
	var hasFlash: Bool { get }
	var hasFrontCamera: Bool { get }
	var supportedCameraPositions: Set<AVCaptureDevicePosition> { get }
	var supportedFeatures: [CameraSupportedFeature] { get }
	
	// Internal API
	func connectCameraToView(previewView: UIView, completion: ((Bool, ErrorType?)-> ())?)
	func setCameraPosition(position: AVCaptureDevicePosition) throws
	func setFlashMode(mode: AVCaptureFlashMode) throws
	func takePhoto(completion: ((UIImage?, ErrorType?)->())?)
}

// MARK:- State

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
public enum CameraControllerSetupResult: String {
	case ConfigurationFailed = "ConfigurationFailed"
	case NotAuthorized = "NotAuthorized"
	case NotDetermined = "NotDetermined"
	case Restricted = "Restricted"
	case Running = "Running"
	case Success = "Success"
	case Stopped = "Stopped"
}

/*!
@enum CameraOutputMode
@abstract
CameraOutputMode represents possibilities for camera output (e.g. still image and video)
*/
public enum CameraOutputMode {
	case StillImage
	case Video
}

/*!
@error CaptureQuality
@abstract
`CaptureQuality` represents AVCaptureSessionPreset camera quality
*/
public enum CaptureQuality {
	case High
	case Medium
	case Low
}

/*!
@enum CameraSupportedFeature
@abstract
CameraSupportedFeature represents hardware features of CameraController managed camera
*/
public enum CameraSupportedFeature {
	case Flash
	case FrontCamera
}

// MARK:- Errors

/*!
@error CameraControllerError
@abstract
`CameraControllerError` represents CameraController API-level error resulting from incorrect usage.

@discussion
CameraController successful operation depends on correctly connecting the camera to a previewLayer.
*/
public enum CameraControllerError: ErrorType {
	case ImageCaptureFailed
	case NotRunning
	case DeviceDoesNotSupportFeature
	case WrongConfiguration
}

/*!
@error CameraControllerPreviewLayerError
@abstract
`CameraControllerVideoDeviceError` represents CameraController video device error possibilities.

@discussion
Camera controller may fail to function due to a variety of setup and permissions errors represented in this enum.
*/
public enum CameraControllerPreviewLayerError: ErrorType {
	case NotFound
	case SetupFailed
}

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

// MARK:- Observer/Subject Design Pattern

/*!
@interface CameraControllerObserver
@abstract
`CameraControllerObserver` is an interface that camera controller observers conform to in order to be notified of camera controller updates.
*/
public protocol CameraControllerObserver: class {
	func updatePropertyWithName(propertyName: String, value: AnyObject?)
}
/*!
@interface CameraControllerSubject
@abstract
`CameraControllerSubject` is an interface that camera controller data controller objects conform to in order to notify observers of property changes.
*/
public protocol CameraControllerSubject {
	func subscribe(observer: CameraControllerObserver)
	func unsubscribe(observer: CameraControllerObserver)
}
