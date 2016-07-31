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
  static func setInputsForVideoDevice(_ videoDevice: AVCaptureDevice,
                                      input: AVCaptureDeviceInput,
                                      session: AVCaptureSession) throws
  static func addOutputsToSession(_ session: AVCaptureSession,
                                  outputMode: CameraOutputMode,
                                  sessionQueue: DispatchQueue,
                                  completion: CaptureSessionCallback)
  static func addAudioInputToSession(_ session: AVCaptureSession,
                                      sessionQueue: DispatchQueue,
                                      completion: ((Bool) -> ())?)
  static func addMovieOutputToSession(_ session: AVCaptureSession,
                                       sessionQueue: DispatchQueue,
                                       completion: MovieFileOutputCallback)
  static func addStillImageOutputToSession(_ session: AVCaptureSession,
                                            sessionQueue: DispatchQueue,
                                            completion: StillImageOutputCallback)
}

struct AVCaptureSessionMaker: CaptureSessionMaker {

  static func setInputsForVideoDevice(_ videoDevice: AVCaptureDevice,
                                      input: AVCaptureDeviceInput,
                                      session: AVCaptureSession) throws {
    // add inputs and commit config
    session.beginConfiguration()
    session.sessionPreset = AVCaptureSessionPresetHigh

    guard session.canAddInput(input) else {
      throw CameraControllerError.setupFailed
    }

    session.addInput(input)
    session.commitConfiguration()
  }

  static func addAudioInputToSession(_ session: AVCaptureSession,
                                      sessionQueue: DispatchQueue,
                                      completion: ((Bool) -> ())?) {
    session.beginConfiguration()
    sessionQueue.async(execute: {
      addAudioInputToSession(session)
      session.commitConfiguration()
      DispatchQueue.main.async(execute: {
        completion?(true)
      })
    })
  }

  static func addOutputsToSession(_ session: AVCaptureSession,
                                  outputMode: CameraOutputMode,
                                  sessionQueue: DispatchQueue,
                                  completion: CaptureSessionCallback) {
    session.beginConfiguration()
    sessionQueue.async(execute: { () in

      var movieFileOutput: AVCaptureMovieFileOutput?
      var stillImageOutput: AVCaptureStillImageOutput?
      switch outputMode {
      case .both:
        addAudioInputToSession(session)
        movieFileOutput = addMovieFileOutputToSession(session)
        stillImageOutput = addStillImageOutputToSession(session)
      case .stillImage:
        stillImageOutput = addStillImageOutputToSession(session)
      case .video:
        movieFileOutput = addMovieFileOutputToSession(session)
      }
      session.commitConfiguration()
      DispatchQueue.main.async(execute: {
        completion?(movieFileOutput: movieFileOutput,
          imageOutput: stillImageOutput)
      })
    })
  }

  static func addMovieOutputToSession(_ session: AVCaptureSession,
                                       sessionQueue: DispatchQueue,
                                       completion: MovieFileOutputCallback) {
    session.beginConfiguration()
    sessionQueue.async(execute: { () in
      addAudioInputToSession(session)
      let movieFileOutput = addMovieFileOutputToSession(session)

      session.commitConfiguration()

      DispatchQueue.main.async(execute: {
        completion?(movieFileOutput: movieFileOutput)
      })
    })
  }

  // Sets up the capture session. Assumes that authorization status has
  // already been checked.
  // Note: AVCaptureSession.startRunning is synchronous and might take a while to
  // execute. For this reason, we start the session on the coordinated shared `sessionQueue`
  // (and use that queue to access the camera in any further actions)
  static func addStillImageOutputToSession(_ session: AVCaptureSession,
                                            sessionQueue: DispatchQueue,
                                            completion: StillImageOutputCallback) {
    session.beginConfiguration()
    sessionQueue.async(execute: { () in

      let stillImageOutput = addStillImageOutputToSession(session)

      session.commitConfiguration()

      DispatchQueue.main.async(execute: {
        completion?(imageOutput: stillImageOutput)
      })
    })
  }

  // MARK: Private

  /// Important: This is a helper function and must be used in conjunction with session queue work
  private static func addAudioInputToSession(_ session: AVCaptureSession) {
    guard let mic = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) else {
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
  private static func addMovieFileOutputToSession(_ session: AVCaptureSession)
    -> AVCaptureMovieFileOutput {
    let movieFileOutput = AVCaptureMovieFileOutput()
    movieFileOutput.maxRecordedDuration = CMTimeMakeWithSeconds(10, 30)
    movieFileOutput.minFreeDiskSpaceLimit = 1024 * 1024
    if session.canAddOutput(movieFileOutput) {
      session.addOutput(movieFileOutput)
    }
    return movieFileOutput
  }

  /// Important: This is a helper function and must be used in conjunction with session queue work
  private static func addStillImageOutputToSession(_ session: AVCaptureSession)
    -> AVCaptureStillImageOutput {
      let stillImageOutput = AVCaptureStillImageOutput()

      if session.canAddOutput(stillImageOutput) {
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        session.addOutput(stillImageOutput)
      }
      return stillImageOutput
  }
}
