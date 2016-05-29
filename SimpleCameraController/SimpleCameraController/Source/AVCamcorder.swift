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

public class AVCamcorder: NSObject, Camcorder {
  private weak var captureSession: AVCaptureSession?

  required public init(captureSession: AVCaptureSession?) {
    self.captureSession = captureSession
    super.init()
  }

  public func startVideoRecording() {
  }

  public func stopVideoRecording() {
    //
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
  private lazy var movieOutput: AVCaptureMovieFileOutput? = {
    let movieOutput = AVCaptureMovieFileOutput()
    movieOutput.movieFragmentInterval = kCMTimeInvalid

    guard let captureSession = self.captureSession else { return nil }

    captureSession.beginConfiguration()
    captureSession.addOutput(movieOutput)
    captureSession.commitConfiguration()

    return movieOutput
  }()
}

extension AVCamcorder: AVCaptureFileOutputRecordingDelegate {
  public func captureOutput(
    captureOutput: AVCaptureFileOutput!,
    didStartRecordingToOutputFileAtURL fileURL: NSURL!,
                                       fromConnections connections: [AnyObject]!) {
    //
  }

  public func captureOutput(
    captureOutput: AVCaptureFileOutput!,
    didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!,
                                        fromConnections connections: [AnyObject]!,
                                                        error: NSError!) {
  }
}
