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

  static func requestAccessForAudio(_ completion: AuthorizationBlock)
  static func requestAccessForVideo(_ completion: AuthorizationBlock)
}

struct AVAuthorizer: Authorizer {
  fileprivate static let camera: Camera.Type = AVCamera.self
  fileprivate static let authorizationBlock: (_ granted: Bool, _ block: AuthorizationBlock) -> ()
    = { granted, block in
      DispatchQueue.main.async(execute: {
        block?(granted)
      })
  }

  static var audioStatus: AVAuthorizationStatus {
    return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
  }
  static var videoStatus: AVAuthorizationStatus {
    return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
  }

  static var supportsFlash: Bool {
    return camera.backCaptureDevice?.hasFlash ?? false
  }

  static var supportsFrontCamera: Bool {
    return AVFoundationCameraController
      .availableCaptureDevicePositionsWithMediaType(AVMediaTypeVideo).contains(.front)
  }

  static func requestAccessForAudio(_ completion: ((Bool) -> ())?) {
    AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio,
                                              completionHandler: {
                                                authorizationBlock($0, completion)
    })
  }

  static func requestAccessForVideo(_ completion: ((Bool) -> ())?) {
    AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo,
                                              completionHandler: {
                                                authorizationBlock($0, completion)
    })
  }
}
