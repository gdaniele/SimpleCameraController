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
public protocol CameraController {
  var authorizationStatus: AVAuthorizationStatus { get }
  var cameraPosition: AVCaptureDevicePosition { get }
  var captureQuality: CaptureQuality { get }
  var flashMode: AVCaptureFlashMode { get }
  var supportsFlash: Bool { get }
  var supportsFrontCamera: Bool { get }

  func connectCameraToView(previewView: UIView, completion: ConnectCameraControllerCallback)
  func setCameraPosition(position: AVCaptureDevicePosition) throws
  func setFlashMode(mode: AVCaptureFlashMode) throws
  func takePhoto(completion: ImageCaptureCallback)
  func startVideoRecording()
  func stopVideoRecording(completion: VideoCaptureCallback)
}

public typealias ImageCaptureCallback = ((image: UIImage?, error: ErrorType?) -> ())?
public typealias VideoCaptureCallback = ((file: NSURL?, error: ErrorType?) -> ())?
public typealias ConnectCameraControllerCallback = ((didSucceed: Bool, error: ErrorType?)-> ())?

// MARK:- State

/*!
 @enum CameraControllerSetupResult
 @abstract
 Constants indicating the result of CameraController set up.

 @constant ConfigurationFailed
 Indicates that an error occurred and the camera capture configuration failed.
 @constant NotAuthorized
 Indicates that the user has not authorized camera usage and must do so before using
 CameraController
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
  case Both
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
 `CameraControllerError` represents CameraController API-level error resulting from incorrect usage
 or other failures
 */
public enum CameraControllerError: ErrorType {
  case ImageCaptureFailed
  case NotRunning
  case SetupFailed
  case WrongConfiguration
}

/*!
 @error CameraControllerVideoDeviceError
 @abstract
 `CameraControllerVideoDeviceError` represents CameraController video device error possibilities.

 @discussion
 Camera controller may fail to function due to a variety of setup and permissions errors
 represented in this enum.
 */
public enum CameraControllerAuthorizationError: ErrorType {
  case NotAuthorized
  case Restricted
  case NotSupported
}
