//
//  AAPLAppDelegate.swift
//  SceneKitReel
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/13.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Application delegate declaration.
 */

import UIKit

@UIApplicationMain
@objc(AAPLAppDelegate)
class AAPLAppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    // hide the status bar
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        application.statusBarHidden = true
        return true
    }
    
}