//
//  AppDelegate.swift
//  SimpleCameraControllerExample
//
//  Created by Giancarlo on 12/5/15.
//  Copyright © 2015 Giancarlo. All rights reserved.
//

import UIKit
import SimpleCameraController

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

  var window: UIWindow?

  func application(application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    window = UIWindow(frame: UIScreen.mainScreen().bounds)
    window?.rootViewController =
      ExampleViewController(cameraController: AVFoundationCameraController())
    window?.makeKeyAndVisible()

    return true
  }
}
