//
//  AVCamera.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation

protocol Camera {
  /// Takes photo via still image output via session queue
  static var cameraSupported: Bool { get }
  static var backCaptureDevice: AVCaptureDevice? { get }
  static var frontCaptureDevice: AVCaptureDevice? { get }

  static func setFlashMode(flashMode: AVCaptureFlashMode,
                           session: AVCaptureSession,
                           backCaptureDevice: AVCaptureDevice) throws
  static func setPosition(position: AVCaptureDevicePosition,
                          session: AVCaptureSession) throws -> AVCaptureDeviceInput
  static func takePhoto(sessionQueue: dispatch_queue_t,
                        stillImageOutput: AVCaptureStillImageOutput,
                        completion: ImageCaptureCallback)
}

typealias StillImageOutputCallback = ((imageOutput: AVCaptureStillImageOutput?,
  error: ErrorType?) -> ())?

class AVCamera: Camera {
  private static var sessionMaker: CaptureSessionMaker.Type = AVCaptureSessionMaker.self

  static var backCaptureDevice: AVCaptureDevice? {
    return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .Back)
  }

  static var frontCaptureDevice: AVCaptureDevice? {
    return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .Front)
  }

  static var cameraSupported: Bool {
    get {
      guard UIImagePickerController
        .isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear)
        || UIImagePickerController
          .isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front)
        else {
          return false
      }
      return true
    }
  }

  static func setFlashMode(flashMode: AVCaptureFlashMode,
                           session: AVCaptureSession,
                           backCaptureDevice: AVCaptureDevice) throws {
    session.beginConfiguration()

    guard backCaptureDevice.hasFlash &&
      backCaptureDevice.isFlashModeSupported(flashMode) else {
        throw CameraControllerAuthorizationError.NotSupported
    }

    try backCaptureDevice.lockForConfiguration()
    backCaptureDevice.flashMode = flashMode
    backCaptureDevice.unlockForConfiguration()

    session.commitConfiguration()
  }

  /*
   Remove any current video inputs before calling
   */
  static func setPosition(position: AVCaptureDevicePosition,
                          session: AVCaptureSession) throws -> AVCaptureDeviceInput {

    guard let videoDevice = try? AVFoundationCameraController
      .deviceWithMediaType(AVMediaTypeVideo, preferredPosition: position),
      let input = try? AVCaptureDeviceInput(device: videoDevice) else {
        throw CameraControllerError.SetupFailed
    }
    try sessionMaker.setInputsForVideoDevice(videoDevice,
                                             input: input,
                                             session: session)
    return input
  }

  static func takePhoto(sessionQueue: dispatch_queue_t,
                        stillImageOutput: AVCaptureStillImageOutput,
                        completion: ImageCaptureCallback) {
    dispatch_async(sessionQueue, {
      let connection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)

      stillImageOutput
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

  // MARK: Private
  private static func getDevice(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
    switch position {
    case .Back:
      return backCaptureDevice
    case .Front:
      return frontCaptureDevice
    case .Unspecified:
      return nil
    }
  }
}
