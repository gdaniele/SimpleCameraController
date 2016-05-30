//
//  AVAuthorizer.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation

protocol Authorizer {
  static var videoStatus: AVAuthorizationStatus { get }
  static var audioStatus: AVAuthorizationStatus { get }
  static var supportsFrontCamera: Bool { get }
  static var supportsFlash: Bool { get }

  static func requestAccessForAudio(completion: ((Bool) -> ())?)
  static func requestAccessForVideo(completion: ((Bool) -> ())?)
}

struct AVAuthorizer: Authorizer {
  private static let camera: Camera.Type = AVCamera.self

  static var audioStatus: AVAuthorizationStatus {
    return AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeAudio)
  }
  static var videoStatus: AVAuthorizationStatus {
    return AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
  }

  static var supportsFlash: Bool {
    return camera.backCaptureDevice?.hasFlash ?? false
  }

  static var supportsFrontCamera: Bool {
    return AVFoundationCameraController
      .availableCaptureDevicePositionsWithMediaType(AVMediaTypeVideo).contains(.Front)
  }

  static func requestAccessForAudio(completion: ((Bool) -> ())?) {
    AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio,
                                              completionHandler: { completion?($0) })
  }

  static func requestAccessForVideo(completion: ((Bool) -> ())?) {
    AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo,
                                              completionHandler: { completion?($0) })
  }
}
