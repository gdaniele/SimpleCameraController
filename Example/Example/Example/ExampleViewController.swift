//
//  ExampleViewController.swift
//  SimpleCameraControllerExample
//
//  Created by Giancarlo on 12/5/15.
//  Copyright © 2015 Giancarlo. All rights reserved.
//

import SimpleCameraController
import UIKit

class ExampleViewController: UIViewController {
  private var cameraController: CameraController
  private lazy var previewView: PreviewView = {
    let view = PreviewView()
    view.translatesAutoresizingMaskIntoConstraints = false

    return view
  }()

  init(cameraController: CameraController) {
    self.cameraController = cameraController

    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let view = UIView(frame: UIScreen.mainScreen().bounds)
    view.addSubview(self.previewView)

    // Sets constraints
    if let uSuperView = self.previewView.superview {
      view.addConstraints(
        [
          NSLayoutConstraint(item: previewView,
            attribute: .Top, relatedBy: .Equal,
            toItem: uSuperView,
            attribute: .Top,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(item: previewView,
            attribute: .Bottom,
            relatedBy: .Equal,
            toItem: uSuperView,
            attribute: .Bottom,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(item: previewView,
            attribute: .Leading,
            relatedBy: .Equal,
            toItem: uSuperView,
            attribute: .Leading,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(item: previewView,
            attribute: .Trailing,
            relatedBy: .Equal,
            toItem: uSuperView,
            attribute: .Trailing,
            multiplier: 1,
            constant: 0)
        ]
      )
    }

    self.view = view
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    cameraController.connectCameraToView(previewView, completion: { didSucceed, error in
      guard didSucceed && error == nil else {
        print("Connect Camera - Error!")
        return
      }
      print("Connect Camera - Success!")
    })
  }
}

func delay(delay:Double, closure:()->()) {
  dispatch_after(
    dispatch_time(
      DISPATCH_TIME_NOW,
      Int64(delay * Double(NSEC_PER_SEC))
    ),
    dispatch_get_main_queue(), closure)
}
