//
//  AVCaptureSessionMaker.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import AVFoundation

internal typealias AudioOutputCallback = ((audioOutput: AVCaptureAudioDataOutput?) -> ())?
internal typealias StillImageOutputCallback = ((imageOutput: AVCaptureStillImageOutput?) -> ())?
internal typealias MovieFileOutputCallback = ((movieFileOutput: AVCaptureMovieFileOutput?) -> ())?
internal typealias CaptureSessionCallback = ((movieFileOutput: AVCaptureMovieFileOutput?,
  imageOutput: AVCaptureStillImageOutput?) -> ())?

protocol CaptureSessionMaker {
  static func setInputsForVideoDevice(videoDevice: AVCaptureDevice,
                                      input: AVCaptureDeviceInput,
                                      session: AVCaptureSession) throws
  static func addOutputsToSession(session: AVCaptureSession,
                                  outputMode: CameraOutputMode,
                                  sessionQueue: dispatch_queue_t,
                                  completion: CaptureSessionCallback)
  static func addAudioInputToSession(session: AVCaptureSession,
                                      sessionQueue: dispatch_queue_t,
                                      completion: ((Bool) -> ())?)
  static func addMovieOutputToSession(session: AVCaptureSession,
                                       sessionQueue: dispatch_queue_t,
                                       completion: MovieFileOutputCallback)
  static func addStillImageOutputToSession(session: AVCaptureSession,
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

  static func addAudioInputToSession(session: AVCaptureSession,
                                      sessionQueue: dispatch_queue_t,
                                      completion: ((Bool) -> ())?) {
    session.beginConfiguration()
    dispatch_async(sessionQueue, {
      addAudioInputToSession(session)
      session.commitConfiguration()
    })
  }

  static func addOutputsToSession(session: AVCaptureSession,
                                  outputMode: CameraOutputMode,
                                  sessionQueue: dispatch_queue_t,
                                  completion: CaptureSessionCallback) {
    session.beginConfiguration()
    dispatch_async(sessionQueue, { () in

      var movieFileOutput: AVCaptureMovieFileOutput?
      var stillImageOutput: AVCaptureStillImageOutput?
      switch outputMode {
      case .Both:
        addAudioInputToSession(session)
        movieFileOutput = addMovieFileOutputToSession(session)
        stillImageOutput = addStillImageOutputToSession(session)
      case .StillImage:
        stillImageOutput = addStillImageOutputToSession(session)
      case .Video:
        movieFileOutput = addMovieFileOutputToSession(session)
      }
      session.commitConfiguration()

      completion?(movieFileOutput: movieFileOutput,
        imageOutput: stillImageOutput)

    })
  }

  static func addMovieOutputToSession(session: AVCaptureSession,
                                       sessionQueue: dispatch_queue_t,
                                       completion: MovieFileOutputCallback) {
    session.beginConfiguration()
    dispatch_async(sessionQueue, { () in
      addAudioInputToSession(session)
      let movieFileOutput = addMovieFileOutputToSession(session)

      session.commitConfiguration()

      completion?(movieFileOutput: movieFileOutput)
    })
  }

  // Sets up the capture session. Assumes that authorization status has
  // already been checked.
  // Note: AVCaptureSession.startRunning is synchronous and might take a while to
  // execute. For this reason, we start the session on the coordinated shared `sessionQueue`
  // (and use that queue to access the camera in any further actions)
  static func addStillImageOutputToSession(session: AVCaptureSession,
                                            sessionQueue: dispatch_queue_t,
                                            completion: StillImageOutputCallback) {
    session.beginConfiguration()
    dispatch_async(sessionQueue, { () in

      let stillImageOutput = addStillImageOutputToSession(session)

      session.commitConfiguration()

      completion?(imageOutput: stillImageOutput)
    })
  }

  // MARK: Private

  /// Important: This is a helper function and must be used in conjunction with session queue work
  private static func addAudioInputToSession(session: AVCaptureSession) {
    guard let mic = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio) else {
      return
    }
    do {
      let micInput = try AVCaptureDeviceInput(device: mic)
      if session.canAddInput(micInput) {
        session.addInput(micInput)
      }
    } catch {
      print("Could not add mic")
    }
  }

  /// Important: This is a helper function and must be used in conjunction with session queue work
  private static func addMovieFileOutputToSession(session: AVCaptureSession) -> AVCaptureMovieFileOutput {
    let movieFileOutput = AVCaptureMovieFileOutput()
    movieFileOutput.maxRecordedDuration = CMTimeMakeWithSeconds(10, 30)
    movieFileOutput.minFreeDiskSpaceLimit = 1024 * 1024
    if session.canAddOutput(movieFileOutput) {
      session.addOutput(movieFileOutput)
    }
    return movieFileOutput
  }

  /// Important: This is a helper function and must be used in conjunction with session queue work
  private static func addStillImageOutputToSession(session: AVCaptureSession)
    -> AVCaptureStillImageOutput {
      let stillImageOutput = AVCaptureStillImageOutput()

      if session.canAddOutput(stillImageOutput) {
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        session.addOutput(stillImageOutput)
      }
      return stillImageOutput
  }
}
