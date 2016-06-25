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
  private var movieFileOutput: AVCaptureMovieFileOutput? = nil
  private var videoDeviceInput: AVCaptureDeviceInput? = nil

  private let authorizer: Authorizer.Type
  private let captureSessionMaker: AVCaptureSessionMaker.Type
  private let camera: Camera.Type
  private let camcorder: Camcorder

  // MARK:-  State
  private var outputMode: CameraOutputMode = .Both
  private var setupResult: CameraControllerSetupResult = .NotDetermined

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
    guard camera.cameraSupported else {
      setupResult = .ConfigurationFailed
      completion?(didSucceed: false, error: CameraControllerAuthorizationError.NotSupported)
      return
    }

    switch setupResult {
    case .Running:
      addPreviewLayerToView(previewView, completion: completion)
    case .ConfigurationFailed:
      completion?(didSucceed: false, error: CameraControllerAuthorizationError.NotSupported)
    case .NotAuthorized, .NotDetermined, .Restricted, .Stopped, .Success:

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
    guard setupResult == .Stopped else {
      print("Session is already running")
      return
    }
    session.startRunning()
  }

  public func startVideoRecording(completion: VideoCaptureCallback = nil) {
    // Request mic access if need be
    switch authorizer.audioStatus {
    case .NotDetermined:
      authorizer.requestAccessForAudio(nil)
    default:
      break
    }

    assertRunningAndAuthorized({ [weak self] success, error in
      guard let strongSelf = self where success && error == nil else {
        completion?(file: nil, error: error ?? CameraControllerError.SetupFailed)
        return
      }

      guard let movieFileOutput = strongSelf.movieFileOutput else {
        strongSelf.captureSessionMaker.addMovieOutputToSession(strongSelf.session,
          sessionQueue: strongSelf.sessionQueue,
          completion: { movieFileOutput in
            guard let movieFileOutput = movieFileOutput else {
              print("Error starting video recording")
              return
            }
            strongSelf.movieFileOutput = movieFileOutput
            strongSelf.camcorder.startVideoRecording(completion,
              movieFileOutput: movieFileOutput,
              session: strongSelf.session,
              sessionQueue: strongSelf.sessionQueue)
        })
        return
      }

      strongSelf.camcorder.startVideoRecording(completion,
        movieFileOutput: movieFileOutput,
        session: strongSelf.session,
        sessionQueue: strongSelf.sessionQueue)
    })
  }

  public func stopVideoRecording(completion: VideoCaptureCallback) {
    guard let movieFileOutput = movieFileOutput else {
      completion?(file: nil, error: CamcorderError.NotRunning)
      return
    }

    camcorder.stopVideoRecording(movieFileOutput, completion: completion)
  }

  public func takePhoto(completion: ImageCaptureCallback) {
    assertRunningAndAuthorized({ [weak self] success, error in
      guard let strongSelf = self where success && error == nil else {
        completion?(image: nil, error: error ?? CameraControllerError.SetupFailed)
        return
      }

      // Create still image output, if needed
      guard let stillImageOutput = strongSelf.stillImageOutput else {
        strongSelf.captureSessionMaker.addStillImageOutputToSession(strongSelf.session,
          sessionQueue: strongSelf.sessionQueue,
          completion: { stillImageOutput in
            guard let stillImageOutput = stillImageOutput
              else {
                completion?(image: nil, error: CameraControllerError.SetupFailed)
                return
            }
            strongSelf.stillImageOutput = stillImageOutput

            strongSelf.camera.takePhoto(strongSelf.sessionQueue,
              stillImageOutput: stillImageOutput,
              completion: completion)
        })
        return
      }
      strongSelf.camera.takePhoto(strongSelf.sessionQueue,
        stillImageOutput: stillImageOutput,
        completion: completion)
    })
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

  /// Helper for take photo, record video
  /// Checks running status
  /// Checks authorization status
  private func assertRunningAndAuthorized(completion: (success: Bool, error: ErrorType?) -> ()) {
    guard setupResult == .Running else {
      switch AVAuthorizer.videoStatus {
      case .Authorized:
        completion(success: false, error: CameraControllerError.NotRunning)
        return
      case .Denied:
        completion(success: false, error: CameraControllerAuthorizationError.NotAuthorized)
        return
      case .NotDetermined:
        completion(success: false, error: CameraControllerError.NotRunning)
        return
      case .Restricted:
        completion(success: false, error: CameraControllerAuthorizationError.Restricted)
        return
      }
    }
    completion(success: true, error: nil)
  }

  // Adds session to preview layer
  private func addPreviewLayerToView(previewView: UIView,
                                     completion: ((Bool, ErrorType?) -> ())?) {
    guard !(previewView.layer.sublayers?.first is AVCaptureVideoPreviewLayer) else {
      return
    }
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
    session.sessionPreset = AVCaptureSessionPresetLow
    captureSessionMaker.addOutputsToSession(session,
                                            outputMode: outputMode,
                                            sessionQueue: sessionQueue,
                                            completion: { movieOutput, imageOutput in
                                              self.stillImageOutput = imageOutput
                                              self.movieFileOutput = movieOutput

                                              dispatch_async(self.sessionQueue, {
                                                self.session.startRunning()
                                                self.setupResult = .Running
                                                self.addPreviewLayerToView(previewView,
                                                  completion: completion)
                                                return
                                              })
    })
  }
}
