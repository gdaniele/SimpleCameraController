//
//  AVAuthorizer.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation

typealias AuthorizationBlock = ((Bool) -> ())?

protocol Authorizer {
  static var videoStatus: AVAuthorizationStatus { get }
  static var audioStatus: AVAuthorizationStatus { get }
  static var supportsFrontCamera: Bool { get }
  static var supportsFlash: Bool { get }

  static func requestAccessForAudio(completion: AuthorizationBlock)
  static func requestAccessForVideo(completion: AuthorizationBlock)
}

struct AVAuthorizer: Authorizer {
  private static let camera: Camera.Type = AVCamera.self
  private static let authorizationBlock: (granted: Bool, block: AuthorizationBlock) -> ()
    = { granted, block in
      dispatch_async(dispatch_get_main_queue(), {
        block?(granted)
      })
  }

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
                                              completionHandler: {
                                                authorizationBlock(granted: $0, block: completion)
    })
  }

  static func requestAccessForVideo(completion: ((Bool) -> ())?) {
    AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo,
                                              completionHandler: {
                                                authorizationBlock(granted: $0, block: completion)
    })
  }
}
