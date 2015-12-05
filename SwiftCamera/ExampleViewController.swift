//
//  ExampleViewController.swift
//  SwiftCamera
//
//  Created by Giancarlo on 12/5/15.
//  Copyright © 2015 Giancarlo. All rights reserved.
//

import UIKit

class ExampleViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
		
		let cameraController = CameraController()
		cameraController.initializeWithPreviewLayer(self.view)
    }
}
