//
//  CameraController.swift
//  SwiftCamera
//
//  Created by Giancarlo on 12/5/15.
//  Copyright © 2015 Giancarlo. All rights reserved.
//

import AVFoundation
import AssetsLibrary
import UIKit

protocol CameraController {
	func addCameraPreviewToView(previewView: UIView)
}

class AVFoundationCameraController: CameraController {
	
	// MARK:- Public API
	func addCameraPreviewToView(previewView: UIView) {
		// TODO: Implementation
	}
}
