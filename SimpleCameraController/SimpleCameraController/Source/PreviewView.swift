//
//  PreviewView.swift
//  Example
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation
import UIKit

public class PreviewView: UIView {
  override public init(frame: CGRect) {
    super.init(frame: frame)

    NSNotificationCenter.defaultCenter()
      .addObserver(self,
                   selector: #selector(PreviewView.orientationChanged),
                   name: UIApplicationDidChangeStatusBarOrientationNotification,
                   object: nil)
  }

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  internal func orientationChanged() {
    let deviceOrientation = UIApplication.sharedApplication().statusBarOrientation

    guard let orientation = AVCaptureVideoOrientationTransformer
      .videoOrientationFromUIInterfaceOrientation(deviceOrientation)
      else {
        return
    }

    guard let layer = previewLayer,
      let connection = layer.connection where connection.supportsVideoOrientation else {
        return
    }

    connection.videoOrientation = orientation
  }

  public override func layoutSubviews() {
    super.layoutSubviews()

    guard let previewLayer = previewLayer else { return }
    previewLayer.frame = bounds
  }

  // MARK: Private

  private var previewLayer: AVCaptureVideoPreviewLayer? {
    return layer.sublayers?.first as? AVCaptureVideoPreviewLayer
  }

}
