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
  private lazy var previewLayer: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.blackColor()
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

  override func viewDidLoad() {
    super.viewDidLoad()

    setUpUI()
  }

  private func setUpUI() {
    // Adds previewLayer
    self.view.addSubview(self.previewLayer)

    // Sets constraints
    if let uSuperView = self.previewLayer.superview {
      self.view.addConstraints(
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

    self.cameraController.connectCameraToView(self.previewLayer, completion: { didSucceed, error in
      guard didSucceed && error == nil else {
        print("Connect Camera - Error!")
        return
      }
      print("Connect Camera - Success!")
    })
  }
}

// MARK: CameraControllerObserver

extension ExampleViewController: CameraControllerObserver {
  func updatePropertyWithName(propertyName: String, value: AnyObject?) {
    print("\(self.self) recieved \(propertyName): \(value)")
  }
}
