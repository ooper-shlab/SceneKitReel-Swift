//
//  AAPLGameView.swift
//  SceneKitReel
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/12.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Game view declaration.
 */

import SceneKit

@objc(AAPLGameView)
class AAPLGameView: SCNView {
    
    @IBOutlet private var _gameViewController: AAPLGameViewController!
    private var _clickLocation: NSPoint = NSPoint()
    
    // forward click event to the game view controller
    override func mouseDown(theEvent: NSEvent) {
        _clickLocation = self.convertPoint(theEvent.locationInWindow, fromView: nil)
        
        _gameViewController.gestureDidBegin()
        
        if theEvent.clickCount == 2 {
            _gameViewController.handleDoubleTapAtPoint(_clickLocation)
        } else {
            if !theEvent.modifierFlags.contains(.AlternateKeyMask) {
                _gameViewController.handleTapAtPoint(_clickLocation)
            }
        }
        
        super.mouseDown(theEvent)
    }
    
    // forward drag event to the view controller as "pan" events
    override func mouseDragged(theEvent: NSEvent) {
        if theEvent.modifierFlags.contains(.AlternateKeyMask) {
            let p = self.convertPoint(theEvent.locationInWindow, fromView: nil)
            _gameViewController.tiltCameraWithOffset(CGPointMake(p.x - _clickLocation.x, p.y - _clickLocation.y))
        } else {
            _gameViewController.handlePanAtPoint(self.convertPoint(theEvent.locationInWindow, fromView: nil))
        }
        
        super.mouseDragged(theEvent)
    }
    
    // forward mouse up events as "end gesture"
    override func mouseUp(theEvent: NSEvent) {
        _gameViewController.gestureDidEnd()
        super.mouseUp(theEvent)
    }
    
}