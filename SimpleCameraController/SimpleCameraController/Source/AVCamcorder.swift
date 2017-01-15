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
  func startVideoRecording(_ completion: VideoCaptureCallback,
                           movieFileOutput: AVCaptureMovieFileOutput,
                           session: AVCaptureSession,
                           sessionQueue: DispatchQueue)
  func stopVideoRecording(_ movieFileOutput: AVCaptureMovieFileOutput,
                          completion: VideoCaptureCallback)
}

typealias CamcorderCallback = ((_ success: Bool, _ error: CamcorderError?) -> ())?

public enum CamcorderError: Error {
  case micError
  case micDenied
  case micRestricted
  case notRunning
}

class AVCamcorder: NSObject, Camcorder {
  fileprivate let authorizer: Authorizer.Type = AVAuthorizer.self
  fileprivate let sessionMaker: CaptureSessionMaker.Type = AVCaptureSessionMaker.self

  fileprivate var videoCompletion: VideoCaptureCallback? =  nil

  func startVideoRecording(_ completion: VideoCaptureCallback = nil,
                           movieFileOutput: AVCaptureMovieFileOutput,
                           session: AVCaptureSession,
                           sessionQueue: DispatchQueue) {
    videoCompletion = completion
    sessionMaker
      .addAudioInputToSession(session,
                              sessionQueue: sessionQueue,
                              completion: { success in
                                movieFileOutput
                                  .startRecording(toOutputFileURL: self.temporaryFilePath,
                                    recordingDelegate: self)
      })
  }

  func stopVideoRecording(_ movieFileOutput: AVCaptureMovieFileOutput,
                          completion: VideoCaptureCallback) {
    if movieFileOutput.isRecording {
      videoCompletion = completion
      movieFileOutput.stopRecording()
    }
  }

  // MARK: Private

  fileprivate static func createMovieOutput(_ session: AVCaptureSession) -> AVCaptureMovieFileOutput {
    let movieOutput = AVCaptureMovieFileOutput()
    movieOutput.movieFragmentInterval = kCMTimeInvalid

    session.beginConfiguration()
    session.addOutput(movieOutput)
    session.commitConfiguration()

    return movieOutput
  }

  // MARK: Private lazy

  fileprivate var temporaryFilePath: URL? = {
    do {
      let temporaryFilePath = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("temporary-recording")
        .appendingPathExtension("mp4")
        .absoluteString
      if FileManager.default.fileExists(atPath: temporaryFilePath) {
        try FileManager.default.removeItem(atPath: temporaryFilePath)
      }
      return URL(string: temporaryFilePath)

    } catch { return nil }
  }()
}

extension AVCamcorder: AVCaptureFileOutputRecordingDelegate {

  func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
    print("recording finished")
    guard let completion = videoCompletion else { return }
    completion?(outputFileURL, error)
  }

  func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
    print("recording started")
  }
}
