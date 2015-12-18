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
	var cameraQuality: CameraQuality { get set }
	var deviceCamera: CameraDevice { get set }
	var flashMode: AVCaptureFlashMode { get set }
	
	// Internal API
	func connectCameraToView(previewView: UIView, completion: ((Bool, ErrorType?)-> ())?)
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
}

/*!
@enum CameraDevice
@abstract
CameraDevice represents a device camera
*/
public enum CameraDevice {
	case Back
	case Front
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
@error CameraQuality
@abstract
`CameraQuality` represents AVCaptureSessionPreset camera quality
*/
public enum CameraQuality {
	case High
	case Medium
	case Low
}

// MARK:- Errors

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
