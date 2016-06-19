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
  func startVideoRecording(completion: VideoCaptureCallback,
                           movieFileOutput: AVCaptureMovieFileOutput,
                           session: AVCaptureSession,
                           sessionQueue: dispatch_queue_t)
  func stopVideoRecording(movieFileOutput: AVCaptureMovieFileOutput,
                          completion: VideoCaptureCallback)
}

typealias CamcorderCallback = ((success: Bool, error: CamcorderError?) -> ())?

public enum CamcorderError: ErrorType {
  case MicError
  case MicDenied
  case MicRestricted
  case NotRunning
}

class AVCamcorder: NSObject, Camcorder {
  private let authorizer: Authorizer.Type = AVAuthorizer.self
  private let sessionMaker: CaptureSessionMaker.Type = AVCaptureSessionMaker.self

  private var videoCompletion: VideoCaptureCallback? =  nil

  func startVideoRecording(completion: VideoCaptureCallback = nil,
                           movieFileOutput: AVCaptureMovieFileOutput,
                           session: AVCaptureSession,
                           sessionQueue: dispatch_queue_t) {
    videoCompletion = completion
    sessionMaker
      .addAudioInputToSession(session,
                              sessionQueue: sessionQueue,
                              completion: { success in
                                movieFileOutput
                                  .startRecordingToOutputFileURL(self.temporaryFilePath,
                                    recordingDelegate: self)
      })
  }

  func stopVideoRecording(movieFileOutput: AVCaptureMovieFileOutput,
                          completion: VideoCaptureCallback) {
    if movieFileOutput.recording {
      videoCompletion = completion
      movieFileOutput.stopRecording()
    }
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
      .URLByAppendingPathComponent("temporary-recording")!
      .URLByAppendingPathExtension("mp4")!
      .absoluteString

    if NSFileManager.defaultManager().fileExistsAtPath(temporaryFilePath!) {
      do {
        try NSFileManager.defaultManager().removeItemAtPath(temporaryFilePath!)
      } catch { }
    }
    return NSURL(string: temporaryFilePath!)!
  }()
}

extension AVCamcorder: AVCaptureFileOutputRecordingDelegate {
  func captureOutput(
    captureOutput: AVCaptureFileOutput!,
    didStartRecordingToOutputFileAtURL fileURL: NSURL!,
                                       fromConnections connections: [AnyObject]!) {
    print("recording started")
  }

  func captureOutput(
    captureOutput: AVCaptureFileOutput!,
    didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!,
                                        fromConnections connections: [AnyObject]!,
                                                        error: NSError!) {
    print("recording finished")
    guard let completion = videoCompletion else { return }
    completion?(file: outputFileURL, error: error)
  }
}
