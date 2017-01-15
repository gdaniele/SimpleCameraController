//
//  AVCamera.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation
import UIKit

protocol Camera {
  /// Takes photo via still image output via session queue
  static var cameraSupported: Bool { get }
  static var backCaptureDevice: AVCaptureDevice? { get }
  static var frontCaptureDevice: AVCaptureDevice? { get }

  static func setFlashMode(_ flashMode: AVCaptureFlashMode,
                           session: AVCaptureSession,
                           backCaptureDevice: AVCaptureDevice) throws
  static func setPosition(_ position: AVCaptureDevicePosition,
                          session: AVCaptureSession) throws -> AVCaptureDeviceInput
  static func takePhoto(_ sessionQueue: DispatchQueue,
                        stillImageOutput: AVCaptureStillImageOutput,
                        completion: ImageCaptureCallback)
}

class AVCamera: Camera {
  fileprivate static var sessionMaker: CaptureSessionMaker.Type = AVCaptureSessionMaker.self

  static var backCaptureDevice: AVCaptureDevice? {
    return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .back)
  }

  static var frontCaptureDevice: AVCaptureDevice? {
    return try? AVFoundationCameraController.deviceWithMediaType(AVMediaTypeVideo, position: .front)
  }

  static var cameraSupported: Bool {
    get {
      guard UIImagePickerController
        .isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.rear)
        || UIImagePickerController
          .isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.front)
        else {
          return false
      }
      return true
    }
  }

  static func setFlashMode(_ flashMode: AVCaptureFlashMode,
                           session: AVCaptureSession,
                           backCaptureDevice: AVCaptureDevice) throws {
    session.beginConfiguration()

    guard backCaptureDevice.hasFlash &&
      backCaptureDevice.isFlashModeSupported(flashMode) else {
        throw CameraControllerAuthorizationError.notSupported
    }

    try backCaptureDevice.lockForConfiguration()
    backCaptureDevice.flashMode = flashMode
    backCaptureDevice.unlockForConfiguration()

    session.commitConfiguration()
  }

  /*
   Remove any current video inputs before calling
   */
  static func setPosition(_ position: AVCaptureDevicePosition,
                          session: AVCaptureSession) throws -> AVCaptureDeviceInput {

    guard let videoDevice = try? AVFoundationCameraController
      .deviceWithMediaType(AVMediaTypeVideo, preferredPosition: position),
      let input = try? AVCaptureDeviceInput(device: videoDevice) else {
        throw CameraControllerError.setupFailed
    }
    try sessionMaker.setInputsForVideoDevice(videoDevice,
                                             input: input,
                                             session: session)
    return input
  }

  static func takePhoto(_ sessionQueue: DispatchQueue,
                        stillImageOutput: AVCaptureStillImageOutput,
                        completion: ImageCaptureCallback) {
    sessionQueue.async(execute: {
      let connection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo)

      stillImageOutput
        .captureStillImageAsynchronously(from: connection,
          completionHandler: { imageDataSampleBuffer, receivedError in
            guard receivedError == nil else {
              completion?(nil, receivedError!)
              return
            }
            if let uImageDataBuffer = imageDataSampleBuffer {
              let imageData = AVCaptureStillImageOutput
                .jpegStillImageNSDataRepresentation(uImageDataBuffer)
              guard let image = UIImage(data: imageData!) else {
                completion?(nil, CameraControllerError.imageCaptureFailed)
                return
              }
              DispatchQueue.main.async(execute: {
                completion?(image, nil)
                return
              })
            }
        })
    })
  }

  // MARK: Private
  fileprivate static func getDevice(_ position: AVCaptureDevicePosition) -> AVCaptureDevice? {
    switch position {
    case .back:
      return backCaptureDevice
    case .front:
      return frontCaptureDevice
    case .unspecified:
      return nil
    }
  }
}
