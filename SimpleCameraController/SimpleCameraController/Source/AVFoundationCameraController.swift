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
open class AVFoundationCameraController: NSObject, CameraController {
  fileprivate typealias CaptureSessionCallback = ((Bool, Error?)->())?

  // MARK:-  Session management
  fileprivate let session: AVCaptureSession
  fileprivate let sessionQueue: DispatchQueue
  fileprivate var stillImageOutput: AVCaptureStillImageOutput? = nil
  fileprivate var movieFileOutput: AVCaptureMovieFileOutput? = nil
  fileprivate var videoDeviceInput: AVCaptureDeviceInput? = nil

  fileprivate let authorizer: Authorizer.Type
  fileprivate let captureSessionMaker: AVCaptureSessionMaker.Type
  fileprivate let camera: Camera.Type
  fileprivate let camcorder: Camcorder

  // MARK:-  State
  fileprivate var outputMode: CameraOutputMode = .both
  fileprivate var setupResult: CameraControllerSetupResult = .NotDetermined

  public override init() {
    self.authorizer = AVAuthorizer.self
    self.session = AVCaptureSession()
    self.camera = AVCamera.self
    self.captureSessionMaker = AVCaptureSessionMaker.self
    self.camcorder = AVCamcorder()
    self.sessionQueue = DispatchQueue(label: "session queue")

    super.init()
  }

  // MARK:- Public Properties

  open var authorizationStatus: AVAuthorizationStatus {
    return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
  }

  open fileprivate(set) var cameraPosition: AVCaptureDevicePosition = .front
  open fileprivate(set) var captureQuality: CaptureQuality = .high
  open fileprivate(set) var flashMode: AVCaptureFlashMode = .off

  open var supportsFlash: Bool {
    return authorizer.supportsFlash
  }
  open var supportsFrontCamera: Bool {
    return authorizer.supportsFrontCamera
  }

  // MARK:- Public Class API

  open class func availableCaptureDevicePositionsWithMediaType(_ mediaType: String)
    -> Set<AVCaptureDevicePosition> {
      return Set(AVCaptureDevice.devices(withMediaType: mediaType).map { ($0 as AnyObject).position })
  }

  // Returns an AVCAptureDevice with the given media type. Throws an error if not available.
  open class func deviceWithMediaType(_ mediaType: String, position: AVCaptureDevicePosition)
    throws -> AVCaptureDevice {
      // Fallback if device with preferred position not available
      let devices = AVCaptureDevice.devices(withMediaType: mediaType)
      let preferredDevice = devices?.filter { device in
        (device as AnyObject).position == position
        }.first

      guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice),
        preferredDevice is AVCaptureDevice else {
          throw CameraControllerAuthorizationError.notSupported
      }

      return uPreferredDevice
  }

  // Returns an AVCAptureDevice with the given media type.
  // Throws an error if not available. Note that if a device with preferredPosition
  // is not available,
  // the first available device is returned.
  open class func deviceWithMediaType(_ mediaType: String,
                                        preferredPosition: AVCaptureDevicePosition)
    throws -> AVCaptureDevice {
      // Fallback if device with preferred position not available
      let devices = AVCaptureDevice.devices(withMediaType: mediaType)
      let defaultDevice = devices?.first
      let preferredDevice = devices?.filter { device in
        (device as AnyObject).position == preferredPosition
        }.first

      guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice),
        preferredDevice is AVCaptureDevice else {

          guard let uDefaultDevice = (defaultDevice as? AVCaptureDevice),
            defaultDevice is AVCaptureDevice else {
              throw CameraControllerAuthorizationError.notSupported
          }
          return uDefaultDevice
      }

      return uPreferredDevice
  }

  // MARK:- Public instance API

  open func connectCameraToView(_ previewView: UIView,
                                  completion: ConnectCameraControllerCallback) {
    guard camera.cameraSupported else {
      setupResult = .ConfigurationFailed
      completion?(false, CameraControllerAuthorizationError.notSupported)
      return
    }

    switch setupResult {
    case .Running:
      addPreviewLayerToView(previewView, completion: completion)
    case .ConfigurationFailed:
      completion?(false, CameraControllerAuthorizationError.notSupported)
    case .NotAuthorized, .NotDetermined, .Restricted, .Stopped, .Success:

      // Check authorization status and requests camera permissions if necessary
      switch authorizer.videoStatus {
      case .denied:
        completion?(false, CameraControllerAuthorizationError.notAuthorized)
      case .restricted:
        completion?(false, CameraControllerAuthorizationError.restricted)
      case .notDetermined:
        authorizer.requestAccessForVideo({ granted in
          guard granted else {
            completion?(false, CameraControllerAuthorizationError.notAuthorized)
            return
          }
          self.configureCamera()
          self.connectCamera(previewView, completion: completion)
        })

      case .authorized:
        self.configureCamera()
        self.connectCamera(previewView, completion: completion)
      }
    }
  }

  open func setCameraPosition(_ position: AVCaptureDevicePosition) throws {
    // Remove current input before setting position
    if let videoDeviceInput = videoDeviceInput {
      session.removeInput(videoDeviceInput)
    }

    let newVideoInput = try camera.setPosition(position,
                                               session: session)
    videoDeviceInput = newVideoInput
    cameraPosition = position
  }

  open func setFlashMode(_ mode: AVCaptureFlashMode) throws {
    guard let captureDevice = camera.backCaptureDevice else {
      throw CameraControllerAuthorizationError.notSupported
    }

    try camera.setFlashMode(mode, session: session, backCaptureDevice: captureDevice)
    flashMode = mode
  }

  open func stopCaptureSession() {
    session.stopRunning()
  }

  open func startCaptureSession() {
    guard !session.isRunning else {
      print("Session is already running")
      return
    }
    guard setupResult == .Stopped else {
      print("Session is already running")
      return
    }
    guard setupResult == .Stopped else {
      print("Session is already running")
      return
    }
    guard setupResult == .Stopped else {
      print("Session is already running")
      return
    }

    self.sessionQueue.async(execute: {
      self.session.startRunning()
    })
  }

  open func startVideoRecording(_ completion: VideoCaptureCallback = nil) {
    // Request mic access if need be
    switch authorizer.audioStatus {
    case .notDetermined:
      authorizer.requestAccessForAudio(nil)
    default:
      break
    }

    assertRunningAndAuthorized({ [weak self] success, error in
      guard let strongSelf = self,
        success && error == nil else {
        completion?(nil, error ?? CameraControllerError.setupFailed)
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

  open func stopVideoRecording(_ completion: VideoCaptureCallback) {
    guard let movieFileOutput = movieFileOutput else {
      completion?(nil, CamcorderError.notRunning)
      return
    }

    camcorder.stopVideoRecording(movieFileOutput, completion: completion)
  }

  open func takePhoto(_ completion: ImageCaptureCallback) {
    assertRunningAndAuthorized({ [weak self] success, error in
      guard let strongSelf = self,
        success && error == nil else {
        completion?(nil, error ?? CameraControllerError.setupFailed)
        return
      }

      // Create still image output, if needed
      guard let stillImageOutput = strongSelf.stillImageOutput else {
        strongSelf.captureSessionMaker.addStillImageOutputToSession(strongSelf.session,
          sessionQueue: strongSelf.sessionQueue,
          completion: { stillImageOutput in
            guard let stillImageOutput = stillImageOutput
              else {
                completion?(nil, CameraControllerError.setupFailed)
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

  fileprivate var previewLayer: AVCaptureVideoPreviewLayer? {
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill

    DispatchQueue.main.async(execute: {
      // We need to dispatch to the main thread here
      // because our preview layer is backed by UIKit
      // which runs on the main thread
      let currentStatusBarOrientation = UIApplication.shared.statusBarOrientation

      guard let connection = previewLayer?.connection,
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
  fileprivate func assertRunningAndAuthorized(_ completion: (_ success: Bool, _ error: Error?) -> ()) {
    guard setupResult == .Running else {
      switch AVAuthorizer.videoStatus {
      case .authorized:
        completion(false, CameraControllerError.notRunning)
        return
      case .denied:
        completion(false, CameraControllerAuthorizationError.notAuthorized)
        return
      case .notDetermined:
        completion(false, CameraControllerError.notRunning)
        return
      case .restricted:
        completion(false, CameraControllerAuthorizationError.restricted)
        return
      }
    }
    completion(true, nil)
  }

  // Adds session to preview layer
  fileprivate func addPreviewLayerToView(_ previewView: UIView,
                                     completion: ((Bool, Error?) -> ())?) {
    guard !(previewView.layer.sublayers?.first is AVCaptureVideoPreviewLayer) else {
      return
    }
    DispatchQueue.main.async {
      guard let previewLayer = self.previewLayer else {
        completion?(false, CameraControllerError.setupFailed)
        return
      }
      previewLayer.frame = previewView.layer.bounds
      previewView.clipsToBounds = true
      previewView.layer.insertSublayer(previewLayer, at: 0)
      completion?(true, nil)
      return
    }
  }

  fileprivate func configureCamera() {
    do {
      try setFlashMode(flashMode)
      try setCameraPosition(cameraPosition)
    } catch {
      print("Failed to configure with desired settings")
    }
  }

  fileprivate func connectCamera(_ previewView: UIView,
                             completion: ConnectCameraControllerCallback) {
    captureSessionMaker.addOutputsToSession(session,
                                            outputMode: outputMode,
                                            sessionQueue: sessionQueue,
                                            completion: { movieOutput, imageOutput in
                                              self.stillImageOutput = imageOutput
                                              self.movieFileOutput = movieOutput

                                              self.sessionQueue.async(execute: {
                                                self.session.startRunning()
                                                self.setupResult = .Running
                                                self.addPreviewLayerToView(previewView,
                                                  completion: completion)
                                                return
                                              })
    })
  }
}
