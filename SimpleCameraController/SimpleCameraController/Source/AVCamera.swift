//
//  AVCamera.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation

protocol Camera {
  func takePhoto(completion: ImageCaptureCallback)
}

class AVCamera: Camera {

  func takePhoto(completion: ImageCaptureCallback) {
    //
  }
}
