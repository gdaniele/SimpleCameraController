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
  private lazy var previewLayer: PreviewView = {
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
    let view = UIView()
    view.addSubview(self.previewLayer)

    // Sets constraints
    if let uSuperView = self.previewLayer.superview {
      view.addConstraints(
        [
          NSLayoutConstraint(item: previewLayer,
            attribute: .Top, relatedBy: .Equal,
            toItem: uSuperView,
            attribute: .Top,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(item: previewLayer,
            attribute: .Bottom,
            relatedBy: .Equal,
            toItem: uSuperView,
            attribute: .Bottom,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(item: previewLayer,
            attribute: .Leading,
            relatedBy: .Equal,
            toItem: uSuperView,
            attribute: .Leading,
            multiplier: 1,
            constant: 0),
          NSLayoutConstraint(item: previewLayer,
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

  override func updateViewConstraints() {
    super.updateViewConstraints()

    if self.view.superview != nil && self.view.constraints.isEmpty {
      let views = ["view": self.view]

      [NSLayoutConstraint.constraintsWithVisualFormat("H:|[view]|",
        options: NSLayoutFormatOptions(rawValue: 0),
        metrics: nil,
        views: views),
       NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|",
        options: NSLayoutFormatOptions(rawValue: 0),
        metrics: nil,
        views: views)].forEach({
          self.view.addConstraints($0)
        })
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    cameraController.connectCameraToView(self.previewLayer, completion: { didSucceed, error in
      guard didSucceed && error == nil else {
        print("Connect Camera - Error!")
        return
      }
      print("Connect Camera - Success!")
    })
  }

  override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
  }
}
