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
  private typealias CaptureSessionCallback = ((Bool, ErrorProtocol?)->())?

  // MARK:-  Session management
  private let session: AVCaptureSession
  private let sessionQueue: DispatchQueue
  private var stillImageOutput: AVCaptureStillImageOutput? = nil
  private var movieFileOutput: AVCaptureMovieFileOutput? = nil
  private var videoDeviceInput: AVCaptureDeviceInput? = nil

  private let authorizer: Authorizer.Type
  private let captureSessionMaker: AVCaptureSessionMaker.Type
  private let camera: Camera.Type
  private let camcorder: Camcorder

  // MARK:-  State
  private var outputMode: CameraOutputMode = .both
  private var setupResult: CameraControllerSetupResult = .NotDetermined

  public override init() {
    self.authorizer = AVAuthorizer.self
    self.session = AVCaptureSession()
    self.camera = AVCamera.self
    self.captureSessionMaker = AVCaptureSessionMaker.self
    self.camcorder = AVCamcorder()
    self.sessionQueue = DispatchQueue(label: "session queue", attributes: DispatchQueueAttributes.serial)

    super.init()

    session.sessionPreset = AVCaptureSessionPresetLow
  }

  // MARK:- Public Properties

  public var authorizationStatus: AVAuthorizationStatus {
    return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
  }

  public private(set) var cameraPosition: AVCaptureDevicePosition = .front
  public private(set) var captureQuality: CaptureQuality = .high
  public private(set) var flashMode: AVCaptureFlashMode = .off

  public var supportsFlash: Bool {
    return authorizer.supportsFlash
  }
  public var supportsFrontCamera: Bool {
    return authorizer.supportsFrontCamera
  }

  // MARK:- Public Class API

  public class func availableCaptureDevicePositionsWithMediaType(_ mediaType: String)
    -> Set<AVCaptureDevicePosition> {
      return Set(AVCaptureDevice.devices(withMediaType: mediaType).map { $0.position })
  }

  // Returns an AVCAptureDevice with the given media type. Throws an error if not available.
  public class func deviceWithMediaType(_ mediaType: String, position: AVCaptureDevicePosition)
    throws -> AVCaptureDevice {
      // Fallback if device with preferred position not available
      let devices = AVCaptureDevice.devices(withMediaType: mediaType)
      let preferredDevice = devices?.filter { device in
        device.position == position
        }.first

      guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice)
        where preferredDevice is AVCaptureDevice else {
          throw CameraControllerAuthorizationError.notSupported
      }

      return uPreferredDevice
  }

  // Returns an AVCAptureDevice with the given media type.
  // Throws an error if not available. Note that if a device with preferredPosition
  // is not available,
  // the first available device is returned.
  public class func deviceWithMediaType(_ mediaType: String,
                                        preferredPosition: AVCaptureDevicePosition)
    throws -> AVCaptureDevice {
      // Fallback if device with preferred position not available
      let devices = AVCaptureDevice.devices(withMediaType: mediaType)
      let defaultDevice = devices?.first
      let preferredDevice = devices?.filter { device in
        device.position == preferredPosition
        }.first

      guard let uPreferredDevice = (preferredDevice as? AVCaptureDevice)
        where preferredDevice is AVCaptureDevice else {

          guard let uDefaultDevice = (defaultDevice as? AVCaptureDevice)
            where defaultDevice is AVCaptureDevice else {
              throw CameraControllerAuthorizationError.notSupported
          }
          return uDefaultDevice
      }

      return uPreferredDevice
  }

  // MARK:- Public instance API

  public func connectCameraToView(_ previewView: UIView,
                                  completion: ConnectCameraControllerCallback) {
    guard camera.cameraSupported else {
      setupResult = .ConfigurationFailed
      completion?(didSucceed: false, error: CameraControllerAuthorizationError.notSupported)
      return
    }

    switch setupResult {
    case .Running:
      addPreviewLayerToView(previewView, completion: completion)
    case .ConfigurationFailed:
      completion?(didSucceed: false, error: CameraControllerAuthorizationError.notSupported)
    case .NotAuthorized, .NotDetermined, .Restricted, .Stopped, .Success:

      // Check authorization status and requests camera permissions if necessary
      switch authorizer.videoStatus {
      case .denied:
        completion?(didSucceed: false, error: CameraControllerAuthorizationError.notAuthorized)
      case .restricted:
        completion?(didSucceed: false, error: CameraControllerAuthorizationError.restricted)
      case .notDetermined:
        authorizer.requestAccessForVideo({ granted in
          guard granted else {
            completion?(didSucceed: false, error: CameraControllerAuthorizationError.notAuthorized)
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

  public func setCameraPosition(_ position: AVCaptureDevicePosition) throws {
    // Remove current input before setting position
    if let videoDeviceInput = videoDeviceInput {
      session.removeInput(videoDeviceInput)
    }

    let newVideoInput = try camera.setPosition(position,
                                               session: session)
    videoDeviceInput = newVideoInput
    cameraPosition = position
  }

  public func setFlashMode(_ mode: AVCaptureFlashMode) throws {
    guard let captureDevice = camera.backCaptureDevice else {
      throw CameraControllerAuthorizationError.notSupported
    }

    try camera.setFlashMode(mode, session: session, backCaptureDevice: captureDevice)
    flashMode = mode
  }

  public func stopCaptureSession() {
    session.stopRunning()
  }

  public func startCaptureSession() {
    guard !session.isRunning else {
      print("Session is already running")
      return
    }
    session.startRunning()
  }

  public func startVideoRecording(_ completion: VideoCaptureCallback = nil) {
    // Request mic access if need be
    switch authorizer.audioStatus {
    case .notDetermined:
      authorizer.requestAccessForAudio(nil)
    default:
      break
    }

    assertRunningAndAuthorized({ [weak self] success, error in
      guard let strongSelf = self where success && error == nil else {
        completion?(file: nil, error: error ?? CameraControllerError.setupFailed)
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

  public func stopVideoRecording(_ completion: VideoCaptureCallback) {
    guard let movieFileOutput = movieFileOutput else {
      completion?(file: nil, error: CamcorderError.notRunning)
      return
    }

    camcorder.stopVideoRecording(movieFileOutput, completion: completion)
  }

  public func takePhoto(_ completion: ImageCaptureCallback) {
    assertRunningAndAuthorized({ [weak self] success, error in
      guard let strongSelf = self where success && error == nil else {
        completion?(image: nil, error: error ?? CameraControllerError.setupFailed)
        return
      }

      // Create still image output, if needed
      guard let stillImageOutput = strongSelf.stillImageOutput else {
        strongSelf.captureSessionMaker.addStillImageOutputToSession(strongSelf.session,
          sessionQueue: strongSelf.sessionQueue,
          completion: { stillImageOutput in
            guard let stillImageOutput = stillImageOutput
              else {
                completion?(image: nil, error: CameraControllerError.setupFailed)
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
    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill

    DispatchQueue.main.async(execute: {
      // We need to dispatch to the main thread here
      // because our preview layer is backed by UIKit
      // which runs on the main thread
      let currentStatusBarOrientation = UIApplication.shared().statusBarOrientation

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
  private func assertRunningAndAuthorized(_ completion: (success: Bool, error: ErrorProtocol?) -> ()) {
    guard setupResult == .Running else {
      switch AVAuthorizer.videoStatus {
      case .authorized:
        completion(success: false, error: CameraControllerError.notRunning)
        return
      case .denied:
        completion(success: false, error: CameraControllerAuthorizationError.notAuthorized)
        return
      case .notDetermined:
        completion(success: false, error: CameraControllerError.notRunning)
        return
      case .restricted:
        completion(success: false, error: CameraControllerAuthorizationError.restricted)
        return
      }
    }
    completion(success: true, error: nil)
  }

  // Adds session to preview layer
  private func addPreviewLayerToView(_ previewView: UIView,
                                     completion: ((Bool, ErrorProtocol?) -> ())?) {
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

  private func configureCamera() {
    do {
      try setFlashMode(flashMode)
      try setCameraPosition(cameraPosition)
    } catch {
      print("Failed to configure with desired settings")
    }
  }

  private func connectCamera(_ previewView: UIView,
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
