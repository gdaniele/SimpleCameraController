//
//  AppDelegate.swift
//  SwiftCamera
//
//  Created by Giancarlo on 12/5/15.
//  Copyright © 2015 Giancarlo. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

	var window: UIWindow?

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
		window?.rootViewController = ExampleViewController(cameraController: AVFoundationCameraController(configurationFailedErrorBlock: nil, notAuthorizedErrorBlock: nil))
		window?.makeKeyAndVisible()
		
		return true
	}
}
