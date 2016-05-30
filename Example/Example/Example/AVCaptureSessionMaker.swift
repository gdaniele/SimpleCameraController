//
//  AVCaptureSessionMaker.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation

internal typealias StillImageOutputCallback = ((imageOutput: AVCaptureStillImageOutput?,
  error: ErrorType?) -> ())?
internal typealias MovieFileOutputCallback = ((movieFileOutput: AVCaptureMovieFileOutput?,
  error: ErrorType?) -> ())?

protocol CaptureSessionMaker {
  static func setInputsForVideoDevice(videoDevice: AVCaptureDevice,
                                      input: AVCaptureDeviceInput,
                                      session: AVCaptureSession) throws
  static func setUpMovieCaptureSession(session: AVCaptureSession,
                                       sessionQueue: dispatch_queue_t,
                                       completion: MovieFileOutputCallback)
  static func setUpStillImageCaptureSession(session: AVCaptureSession,
                                  sessionQueue: dispatch_queue_t,
                                  completion: StillImageOutputCallback)
}

struct AVCaptureSessionMaker: CaptureSessionMaker {

  static func setInputsForVideoDevice(videoDevice: AVCaptureDevice,
                                      input: AVCaptureDeviceInput,
                                      session: AVCaptureSession) throws {
    // add inputs and commit config
    session.beginConfiguration()
    session.sessionPreset = AVCaptureSessionPresetHigh

    guard session.canAddInput(input) else {
      throw CameraControllerError.SetupFailed
    }

    session.addInput(input)
    session.commitConfiguration()
  }

  static func setUpMovieCaptureSession(session: AVCaptureSession,
                                       sessionQueue: dispatch_queue_t,
                                       completion: MovieFileOutputCallback) {
    dispatch_async(sessionQueue, { () in
      // Set Still Image Output
      let movieFileOutput = AVCaptureMovieFileOutput()
      movieFileOutput.maxRecordedDuration = CMTimeMakeWithSeconds(10, 30)
      movieFileOutput.minFreeDiskSpaceLimit = 1024 * 1024
      if session.canAddOutput(movieFileOutput) {
        session.addOutput(movieFileOutput)
      }

      session.commitConfiguration()

      completion?(movieFileOutput: movieFileOutput, error: nil)
    })
  }

  // Sets up the capture session. Assumes that authorization status has
  // already been checked.
  // Note: AVCaptureSession.startRunning is synchronous and might take a while to
  // execute. For this reason, we start the session on the coordinated shared `sessionQueue`
  // (and use that queue to access the camera in any further actions)
  static func setUpStillImageCaptureSession(session: AVCaptureSession,
                                  sessionQueue: dispatch_queue_t,
                                  completion: StillImageOutputCallback) {
    dispatch_async(sessionQueue, { () in
      // Set Still Image Output
      let stillImageOutput = AVCaptureStillImageOutput()

      if session.canAddOutput(stillImageOutput) {
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        session.addOutput(stillImageOutput)
      }

      session.commitConfiguration()

      completion?(imageOutput: stillImageOutput, error: nil)
    })
  }
}
