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
  // MARK:-  Session management
  private let session: AVCaptureSession
  private let sessionQueue: dispatch_queue_t
  private var stillImageOutput: AVCaptureStillImageOutput? = nil
  private var videoDeviceInput: AVCaptureDeviceInput? = nil

  private weak var previewView: UIView? = nil
  private weak var previewLayer: AVCaptureVideoPreviewLayer? = nil

  private let camera: Camera
  private let camcorder: Camcorder

  // MARK:-  State
  private var availableCaptureDevicePositions = Set<AVCaptureDevicePosition>()
  private var outputMode: CameraOutputMode = .StillImage
  private var setupResult: CameraControllerSetupResult = .Success

  // MARK:-  Utilities
  private var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
  private var sessionRunning: Bool = false

  public override init() {
    self.availableCaptureDevicePositions = AVFoundationCameraController
      .availableCaptureDevicePositionsWithMediaType(AVMediaTypeVideo)
    self.session = AVCaptureSession()
    self.camera = AVCamera()
    self.camcorder = AVCamcorder(captureSession: self.session)
    self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL)

    super.init()
  }

  // MARK:- Public Properties

  public var authorizationStatus: AVAuthorizationStatus {
    get {
      return AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
    }
  }

  public private(set) var cameraPosition: AVCaptureDevicePosition = .Unspecified
  public private(set) var captureQuality: CaptureQuality = .High
  public private(set) var flashMode: AVCaptureFlashMode = .Off

  public var supportsFlash: Bool {
    get {
      return backCaptureDevice?.hasFlash ?? false
    }
  }
  public var supportsFrontCamera: Bool {
    get {
      return availableCaptureDevicePositions.contains(.Front) ?? false
    }
  }
  public var supportedCameraPositions: Set<AVCaptureDevicePosition> {
    get {
      return AVFoundationCameraController
        .availableCaptureDevicePositionsWithMediaType(AVMediaTypeVideo)
    }
  }
  public var supportedFeatures: [CameraSupportedFeature] {
    get {
      var supportedFeatures = [CameraSupportedFeature]()
      if supportsFlash { supportedFeatures.append(.Flash) }
      if supportsFrontCamera { supportedFeatures.append(.FrontCamera) }
      return supportedFeatures
    }
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

          guard let uDefdefauaultDevice = (defaultDevice as? AVCaptureDevice)
            where defaultDevice is AVCaptureDevice else {
              throw CameraControllerAuthorizationError.NotSupported
          }
          return uDefdefauaultDevice
      }

      return uPreferredDevice
  }

  // MARK:- Public instance API

  public func connectCameraToView(previewView: UIView, completion: ((Bool, ErrorType?) -> ())?) {
    guard deviceSupportsCamera() else {
      setupResult = .ConfigurationFailed
      completion?(false, CameraControllerAuthorizationError.NotSupported)
      return
    }

    if let previewLayer = previewLayer {
      previewLayer.removeFromSuperlayer()
    }

    if setupResult == .Running {
      addPreviewLayerToView(previewView, completion: completion)
    } else {
      startCaptureWithSuccess({ success, error in
        guard success && error == nil else {
          completion?(success, error)
          return
        }
        self.addPreviewLayerToView(previewView, completion: completion)
      })
    }
  }

  public func setCameraPosition(position: AVCaptureDevicePosition) throws {
    guard position != cameraPosition else {
      return
    }
    try setPosition(position)
  }

  public func setFlashMode(mode: AVCaptureFlashMode) throws {
    guard mode != flashMode else {
      return
    }

    try setFlash(mode)
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

    guard let uStillImageOutput = stillImageOutput where outputMode == .StillImage else {
      completion?(image: nil, error: CameraControllerError.WrongConfiguration)
      return
    }

    dispatch_async(sessionQueue, {
      let connection = uStillImageOutput.connectionWithMediaType(AVMediaTypeVideo)

      uStillImageOutput
        .captureStillImageAsynchronouslyFromConnection(connection,
          completionHandler: { imageDataSampleBuffer, receivedError in
            guard receivedError == nil else {
              completion?(image: nil, error: receivedError!)
              return
            }
            if let uImageDataBuffer = imageDataSampleBuffer {
              let imageData = AVCaptureStillImageOutput
                .jpegStillImageNSDataRepresentation(uImageDataBuffer)
              guard let image = UIImage(data: imageData) else {
                completion?(image: nil, error: CameraControllerError.ImageCaptureFailed)
                return
              }
              dispatch_async(dispatch_get_main_queue(), {
                completion?(image: image, error: nil)
                return
              })
            }
        })
    })
  }

  // MARK:- Private lazy vars

  private lazy var backCaptureDevice: AVCaptureDevice? = {
    return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .Back)
  }()

  private lazy var frontCaptureDevice: AVCaptureDevice? = {
    return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .Front)
  }()

  // MARK:- Private API

  // Adds session to preview layer
  private func addPreviewLayerToView(previewView: UIView,
                                     completion: ((Bool, ErrorType?) -> ())?) {
    self.previewView = previewView
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

  // Checks video authorization status and updates `setupResult`. Note: audio authorization
  // will be requested automatically when an AVCaptureDeviceInput is created.
  private func checkAuthorizationStatus(completion: ((Bool, ErrorType?) -> ())?) {
    switch AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) {
    case .NotDetermined:
      requestAccess(completion)
    case .Denied:
      setupResult = .NotAuthorized
      completion?(false, CameraControllerAuthorizationError.NotAuthorized)
      print("Permission denied")
    case .Restricted:
      setupResult = .ConfigurationFailed
      completion?(false, CameraControllerError.SetupFailed)
      print("Access to the media device is restricted")
      return
    default:
      completion?(true, nil)
      return
    }
  }

  private func deviceSupportsCamera() -> Bool {
    guard UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear)
      || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front)
      else {
        print("Hardware not supported")
        return false
    }
    return true
  }

  private func getDevice(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
    switch position {
    case .Front:
      return frontCaptureDevice
    case .Back:
      return backCaptureDevice
    default: return nil
    }
  }

  // Gives user the option to grant video access. Suspends the session queue to avoid asking the
  // user for audio access (via session queue initialization) if video access has not yet been
  // granted.
  private func requestAccess(completion: ((Bool, ErrorType?) -> ())?) {
    dispatch_suspend(sessionQueue)

    AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
      dispatch_resume(self.sessionQueue)

      guard granted else {
        self.setupResult = .NotAuthorized
        completion?(false, CameraControllerAuthorizationError.NotAuthorized)
        return
      }
      completion?(true, nil)
      return
    })
  }

  private func setCaptureQuality(quality: CaptureQuality) throws {
    guard captureQuality != quality else {
      return
    }
  }

  // Sets up the capture session. Assumes that authorization status has
  // already been checked.
  // Note: AVCaptureSession.startRunning is synchronous and might take a while to
  // execute. For this reason, we start the session on the coordinated shared `sessionQueue`
  // (and use that queue to access the camera in any further actions)
  private func setCaptureSessionWithCompletion(completion: ((Bool, ErrorType?) -> ())?) {
    dispatch_async(sessionQueue, { () in
      guard self.setupResult == .Success else {
        completion?(false, CameraControllerAuthorizationError.NotAuthorized)
        return
      }
      self.backgroundRecordingID = UIBackgroundTaskInvalid

      do {
        try self.setPosition(self.cameraPosition)
      } catch {
        completion?(false, error)
        return
      }

      // Set preview layer
      self.setPreviewLayer()

      self.setPreviewLayerOrientation { previewError in
        completion?(false, CameraControllerError.SetupFailed)
        return
      }

      do {
        try self.setFlash(self.flashMode)
      } catch {
        print("Failed to set flash mode")
      }

      // Set Still Image Output
      let stillImageOutput = AVCaptureStillImageOutput()

      if self.session.canAddOutput(stillImageOutput) {
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        self.session.addOutput(stillImageOutput)
        self.stillImageOutput = stillImageOutput
      }

      self.session.commitConfiguration()

      completion?(true, nil)
    })
  }

  private func setFlash(mode: AVCaptureFlashMode) throws {
    session.beginConfiguration()

    guard let uBackDevice = backCaptureDevice where uBackDevice.hasFlash else {
      throw CameraControllerAuthorizationError.NotSupported
    }

    guard uBackDevice.isFlashModeSupported(mode) else {
      throw CameraControllerAuthorizationError.NotSupported
    }

    try uBackDevice.lockForConfiguration()
    uBackDevice.flashMode = mode
    uBackDevice.unlockForConfiguration()

    flashMode = mode
    session.commitConfiguration()
  }

  private func setPosition(position: AVCaptureDevicePosition) throws {

    switch position {
    case .Unspecified:
      guard let uVideoDevice = try? AVFoundationCameraController
        .deviceWithMediaType(AVMediaTypeVideo, preferredPosition: position),
        let uInput = try? AVCaptureDeviceInput(device: uVideoDevice) else {
          throw CameraControllerError.SetupFailed
      }
      try setInputsForVideoDevice(uVideoDevice, input: uInput)
    default:
      guard let uVideoDevice = getDevice(position),
        let uInput = try? AVCaptureDeviceInput(device: uVideoDevice)
        where supportsCameraPosition(position) else {
          print("Could not get video device")
          throw CameraControllerError.SetupFailed
      }
      try setInputsForVideoDevice(uVideoDevice, input: uInput)
    }

    cameraPosition = position
  }

  private func setInputsForVideoDevice(videoDevice: AVCaptureDevice,
                                       input: AVCaptureDeviceInput) throws {
    // add inputs and commit config
    session.beginConfiguration()

    session.sessionPreset = AVCaptureSessionPresetHigh

    if let uVideoDeviceInput = videoDeviceInput {
      session.removeInput(uVideoDeviceInput)
    }

    guard session.canAddInput(input) else {
      throw CameraControllerError.SetupFailed
    }

    session.addInput(input)
    videoDeviceInput = input

    session.commitConfiguration()
  }

  private func setPreviewLayer() {
    previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
  }

  private func setPreviewLayerOrientation(error: ((CameraControllerError) -> ())?) {
    guard let previewLayer = previewLayer else {
      error?(CameraControllerError.SetupFailed)
      return
    }

    dispatch_async(dispatch_get_main_queue(), {
      // We need to dispatch to the main thread here
      // because our preview layer is backed by UIKit
      // which runs on the main thread
      let currentStatusBarOrientation = UIApplication.sharedApplication().statusBarOrientation

      guard let uConnection = previewLayer.connection,
        let newOrientation =
          AVCaptureVideoOrientationTransformer
            .videoOrientationFromUIInterfaceOrientation(currentStatusBarOrientation) else {
              return
      }
      uConnection.videoOrientation = .Portrait
      uConnection.videoOrientation = newOrientation
    })
  }

  private func startCaptureWithSuccess(completion: ((Bool, ErrorType?)->())?) {
    // Check authorization status and requests camera permissions if necessary
    checkAuthorizationStatus({ didSucceed, error in
      guard didSucceed && error == nil else {
        completion?(false, error)
        return
      }
    })

    // Set up the capture session
    setCaptureSessionWithCompletion({ didSucceed, error in
      guard didSucceed && error == nil else {
        print("Capture error")
        completion?(false, error)
        return
      }
      dispatch_async(self.sessionQueue, {
        self.session.startRunning()
        self.setupResult = .Running
        completion?(true, nil)
        return
      })
    })
  }

  private func supportsCameraPosition(postition: AVCaptureDevicePosition) -> Bool {
    guard !availableCaptureDevicePositions.isEmpty else {
      availableCaptureDevicePositions = AVFoundationCameraController
        .availableCaptureDevicePositionsWithMediaType(AVMediaTypeVideo)
      return availableCaptureDevicePositions.contains(postition)
    }
    return availableCaptureDevicePositions.contains(postition)
  }
}
