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

typealias CamcorderCallback = ((success: Bool, error: CamcorderError?) -> ())?

public enum CamcorderError: ErrorProtocol {
  case micError
  case micDenied
  case micRestricted
  case notRunning
}

class AVCamcorder: NSObject, Camcorder {
  private let authorizer: Authorizer.Type = AVAuthorizer.self
  private let sessionMaker: CaptureSessionMaker.Type = AVCaptureSessionMaker.self

  private var videoCompletion: VideoCaptureCallback? =  nil

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

  private static func createMovieOutput(_ session: AVCaptureSession) -> AVCaptureMovieFileOutput {
    let movieOutput = AVCaptureMovieFileOutput()
    movieOutput.movieFragmentInterval = kCMTimeInvalid

    session.beginConfiguration()
    session.addOutput(movieOutput)
    session.commitConfiguration()

    return movieOutput
  }

  // MARK: Private lazy

  private var temporaryFilePath: URL? = {
    do {
      guard let temporaryFilePath = try? URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("temporary-recording")
        .appendingPathExtension("mp4")
        .absoluteString else {
          fatalError()
      }
      guard let temporaryFilepath = temporaryFilePath else { fatalError() }
      if FileManager.default().fileExists(atPath: temporaryFilepath) {
        try FileManager.default().removeItem(atPath: temporaryFilepath)
      }
      return URL(string: temporaryFilepath)

    } catch { return nil }
  }()
}

extension AVCamcorder: AVCaptureFileOutputRecordingDelegate {
  func capture(
    _ captureOutput: AVCaptureFileOutput!,
    didStartRecordingToOutputFileAt fileURL: URL!,
                                       fromConnections connections: [AnyObject]!) {
    print("recording started")
  }

  func capture(
    _ captureOutput: AVCaptureFileOutput!,
    didFinishRecordingToOutputFileAt outputFileURL: URL!,
                                        fromConnections connections: [AnyObject]!,
                                                        error: NSError!) {
    print("recording finished")
    guard let completion = videoCompletion else { return }
    completion?(file: outputFileURL, error: error)
  }
}
