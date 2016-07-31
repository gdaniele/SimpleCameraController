//
//  AVCaptureVideoOrientationTransformer.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 4/15/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation
import UIKit

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
  static func videoOrientationFromUIInterfaceOrientation(_ orientation: UIInterfaceOrientation)
    -> AVCaptureVideoOrientation? {
    switch orientation {
    case .portrait:
      return .portrait
    case .portraitUpsideDown:
      return .portraitUpsideDown
    case .landscapeRight:
      return .landscapeRight
    case .landscapeLeft:
      return .landscapeLeft
    default: return nil
    }
  }
}
