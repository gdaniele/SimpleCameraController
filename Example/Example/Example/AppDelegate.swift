//
//  AppDelegate.swift
//  Example
//
//  Created by Giancarlo on 5/29/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import SimpleCameraController
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow? = UIWindow(frame: UIScreen.mainScreen().bounds)

  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

    window?.rootViewController = ExampleViewController(cameraController: AVFoundationCameraController())
    window?.makeKeyAndVisible()

    return true
  }

}
