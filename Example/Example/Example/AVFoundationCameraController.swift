/*
 File:  CameraController.swift

 Copyright © 2015 Giancarlo Daniele. All rights reserved.
 */

import AVFoundation
import Photos
import UIKit

/*!
 @class AVFoundationCameraController
 @abstract
 An AVFoundationCameraController is a CameraController that uses AVFoundation to manage an iOS
 camera session accordintakePhotog to set up details.

 @discussion
 An AVFoundationCameraController uses the AVFoundation framework to manage a camera session
 in iOS 9+.
 */
public class AVFoundationCameraController: NSObject, CameraController {
  private typealias CaptureSessionCallback = ((Bool, ErrorType?)->())?

  // MARK:-  Session management
  private let session: AVCaptureSession
  private let sessionQueue: dispatch_queue_t
  private var stillImageOutput: AVCaptureStillImageOutput? = nil
  private var videoDeviceInput: AVCaptureDeviceInput? = nil

  private let authorizer: Authorizer.Type
  private let captureSessionMaker: AVCaptureSessionMaker.Type
  private let camera: Camera.Type
  private let camcorder: Camcorder

  // MARK:-  State
  private var outputMode: CameraOutputMode = .StillImage
  private var setupResult: CameraControllerSetupResult = .NotDetermined
  // used to automatically update device orientation changes in video recording
  private weak var previewView: UIView?

  public override init() {
    self.authorizer = AVAuthorizer.self
    self.session = AVCaptureSession()
    self.camera = AVCamera.self
    self.captureSessionMaker = AVCaptureSessionMaker.self
    self.camcorder = AVCamcorder()
    self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL)

    super.init()
  }

  // MARK:- Public Properties

  public var authorizationStatus: AVAuthorizationStatus {
    return AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
  }

  public private(set) var cameraPosition: AVCaptureDevicePosition = .Front
  public private(set) var captureQuality: CaptureQuality = .High
  public private(set) var flashMode: AVCaptureFlashMode = .Off

  public var supportsFlash: Bool {
    return authorizer.supportsFlash
  }
  public var supportsFrontCamera: Bool {
    return authorizer.supportsFrontCamera
  }

  // MARK:- Public Class API

  public class func availableCaptureDevicePositionsWithMediaType(mediaType: String)
    -> Set<AVCaptureDevicePosition> {
      return Set(AVCaptureDevice.devicesWithMediaType(mediaType).map { $0.position })
  }

  // Returns an AVCAptureDevice with the given media type. Throws an error if not available.
  public class func deviceWithMediaType(mediaType: String, position: AVCaptureDevicePosition)
    throws -> AVCaptureDevice {
      // Fallback if device with preferred position not available
      let devices = AVCaptureDevice.devicesWithMediaType(mediaType)
      let preferredDevice = devices.filter { device in
        device.position == position
        }.first

      guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice)
        where preferredDevice is AVCaptureDevice else {
          throw CameraControllerAuthorizationError.NotSupported
      }

      return uPreferredDevice
  }

  // Returns an AVCAptureDevice with the given media type.
  // Throws an error if not available. Note that if a device with preferredPosition
  // is not available,
  // the first available device is returned.
  public class func deviceWithMediaType(mediaType: String,
                                        preferredPosition: AVCaptureDevicePosition)
    throws -> AVCaptureDevice {
      // Fallback if device with preferred position not available
      let devices = AVCaptureDevice.devicesWithMediaType(mediaType)
      let defaultDevice = devices.first
      let preferredDevice = devices.filter { device in
        device.position == preferredPosition
        }.first

      guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice)
        where preferredDevice is AVCaptureDevice else {

          guard let uDefaultDevice = (defaultDevice as? AVCaptureDevice)
            where defaultDevice is AVCaptureDevice else {
              throw CameraControllerAuthorizationError.NotSupported
          }
          return uDefaultDevice
      }

      return uPreferredDevice
  }

  // MARK:- Public instance API

  public func connectCameraToView(previewView: UIView,
                                  completion: ConnectCameraControllerCallback) {
    self.previewView = previewView

    guard camera.cameraSupported else {
      setupResult = .ConfigurationFailed
      completion?(didSucceed: false, error: CameraControllerAuthorizationError.NotSupported)
      return
    }

    switch setupResult {
    case .Running:
      addPreviewLayerToView(previewView, completion: completion)
    case .ConfigurationFailed, .NotAuthorized, .NotDetermined, .Restricted, .Stopped, .Success:

      // Check authorization status and requests camera permissions if necessary
      switch authorizer.videoStatus {
      case .Denied:
        completion?(didSucceed: false, error: CameraControllerAuthorizationError.NotAuthorized)
      case .Restricted:
        completion?(didSucceed: false, error: CameraControllerAuthorizationError.Restricted)
      case .NotDetermined:
        authorizer.requestAccessForVideo({ granted in
          guard granted else {
            completion?(didSucceed: false, error: CameraControllerAuthorizationError.NotAuthorized)
            return
          }
          self.configureCamera()
          self.connectCamera(previewView, completion: completion)
        })

      case .Authorized:
        self.configureCamera()
        self.connectCamera(previewView, completion: completion)
      }
    }
  }

  public func setCameraPosition(position: AVCaptureDevicePosition) throws {
    // Remove current input before setting position
    if let videoDeviceInput = videoDeviceInput {
      session.removeInput(videoDeviceInput)
    }

    let newVideoInput = try camera.setPosition(position,
                                               session: session)
    videoDeviceInput = newVideoInput
    cameraPosition = position
  }

  public func setFlashMode(mode: AVCaptureFlashMode) throws {
    guard let captureDevice = camera.backCaptureDevice else {
      throw CameraControllerAuthorizationError.NotSupported
    }

    try camera.setFlashMode(mode, session: session, backCaptureDevice: captureDevice)
    flashMode = mode
  }

  public func stopCaptureSession() {
    session.stopRunning()
  }

  public func startCaptureSession() {
    guard !session.running else {
      print("Session is already running")
      return
    }
    session.startRunning()
  }

  public func startVideoRecording() {
    stillImageOutput = nil
    camcorder.startVideoRecording()
  }

  public func stopVideoRecording(completion: VideoCaptureCallback) {
    camcorder.stopVideoRecording()
  }

  public func takePhoto(completion: ImageCaptureCallback) {
    guard setupResult == .Running else {
      completion?(image: nil, error: CameraControllerError.NotRunning)
      return
    }
    guard let stillImageOutput = stillImageOutput else {
      completion?(image: nil, error: CameraControllerError.WrongConfiguration)
      return
    }
    camera.takePhoto(sessionQueue,
                     stillImageOutput: stillImageOutput,
                     completion: completion)
  }

  // MARK:- Private lazy vars

  private var previewLayer: AVCaptureVideoPreviewLayer? {
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill

    dispatch_async(dispatch_get_main_queue(), {
      // We need to dispatch to the main thread here
      // because our preview layer is backed by UIKit
      // which runs on the main thread
      let currentStatusBarOrientation = UIApplication.sharedApplication().statusBarOrientation

      guard let connection = previewLayer.connection,
        let newOrientation =
        AVCaptureVideoOrientationTransformer
          .videoOrientationFromUIInterfaceOrientation(currentStatusBarOrientation) else {
            return
      }
      connection.videoOrientation = newOrientation
    })
    return previewLayer
  }

  // MARK:- Private API

  // Adds session to preview layer
  private func addPreviewLayerToView(previewView: UIView,
                                     completion: ((Bool, ErrorType?) -> ())?) {
    dispatch_async(dispatch_get_main_queue()) {
      guard let previewLayer = self.previewLayer else {
        completion?(false, CameraControllerError.SetupFailed)
        return
      }
      previewLayer.frame = previewView.layer.bounds
      previewView.clipsToBounds = true
      previewView.layer.insertSublayer(previewLayer, atIndex: 0)
      completion?(true, nil)
      return
    }
  }

  private func configureCamera() {
    do {
      try setFlashMode(flashMode)
      try setCameraPosition(cameraPosition)
    } catch {
      print("Failed to configure with desired settings")
    }
  }

  private func connectCamera(previewView: UIView,
                             completion: ConnectCameraControllerCallback) {
    captureSessionMaker.setUpStillImageCaptureSession(session,
                                                      sessionQueue: sessionQueue,
                                                      completion: { imageOutput, error in
                                                        guard let imageOutput = imageOutput
                                                          where error == nil else {
                                                            completion?(didSucceed: false, error: error)
                                                            return
                                                        }
                                                        self.stillImageOutput = imageOutput
                                                        dispatch_async(self.sessionQueue, {
                                                          self.session.startRunning()
                                                          self.setupResult = .Running
                                                          completion?(didSucceed: true, error: nil)
                                                          self.addPreviewLayerToView(previewView, completion: completion)
                                                          return
                                                        })
    })
  }
}
