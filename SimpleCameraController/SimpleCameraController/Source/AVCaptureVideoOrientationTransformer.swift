//
//  AVCaptureVideoOrientationTransformer.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 4/15/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation

/*!
 @struct AVCaptureVideoOrientationTransformer
 @abstract
 AVCaptureVideoOrientation is an enum representing the desired orientation of an AVFoundation
 capture.

 @discussion
 `fromUIInterfaceOrientation()` allows easy conversion from the enum representing
 the current iOS device's UI and the enum representing AVFoundation orientation possibilities.
 */
struct AVCaptureVideoOrientationTransformer {
  static func videoOrientationFromUIInterfaceOrientation(orientation: UIInterfaceOrientation)
    -> AVCaptureVideoOrientation? {
    switch orientation {
    case .Portrait:
      return .Portrait
    case .PortraitUpsideDown:
      return .PortraitUpsideDown
    case .LandscapeRight:
      return .LandscapeRight
    case .LandscapeLeft:
      return .LandscapeLeft
    default: return nil
    }
  }
}
