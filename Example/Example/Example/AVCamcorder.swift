//
//  AVCamcorder.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 4/15/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation
import Foundation

// MARK: Internal interfaces defining more specific camera concerns

protocol Camcorder {
  func startVideoRecording()
  func stopVideoRecording()
}

class AVCamcorder: NSObject, Camcorder {

  func startVideoRecording() {

  }

  func stopVideoRecording() {
    //
  }

  // MARK: Private

  private static func createMovieOutput(session: AVCaptureSession) -> AVCaptureMovieFileOutput {
    let movieOutput = AVCaptureMovieFileOutput()
    movieOutput.movieFragmentInterval = kCMTimeInvalid

    session.beginConfiguration()
    session.addOutput(movieOutput)
    session.commitConfiguration()

    return movieOutput
  }

  // MARK: Private lazy

  private var temporaryFilePath: NSURL = {
    let temporaryFilePath = NSURL(fileURLWithPath: NSTemporaryDirectory())
      .URLByAppendingPathComponent("temporary-recording")
      .URLByAppendingPathExtension("mp4")
      .absoluteString

    if NSFileManager.defaultManager().fileExistsAtPath(temporaryFilePath) {
      do {
        try NSFileManager.defaultManager().removeItemAtPath(temporaryFilePath)
      } catch { }
    }
    return NSURL(string: temporaryFilePath)!
  }()
  private lazy var mic: AVCaptureDevice? = {
    return AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
  }()
}

extension AVCamcorder: AVCaptureFileOutputRecordingDelegate {
  func captureOutput(
    captureOutput: AVCaptureFileOutput!,
    didStartRecordingToOutputFileAtURL fileURL: NSURL!,
                                       fromConnections connections: [AnyObject]!) {
    //
  }

  func captureOutput(
    captureOutput: AVCaptureFileOutput!,
    didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!,
                                        fromConnections connections: [AnyObject]!,
                                                        error: NSError!) {
  }
}
