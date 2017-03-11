//
//  AAPLGameView.swift
//  SceneKitReel
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/12.
//
//
/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
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
    override func mouseDown(with theEvent: NSEvent) {
        _clickLocation = self.convert(theEvent.locationInWindow, from: nil)
        
        _gameViewController.gestureDidBegin()
        
        if theEvent.clickCount == 2 {
            _gameViewController.handleDoubleTapAtPoint(_clickLocation)
        } else {
            if !theEvent.modifierFlags.contains(.option) {
                _gameViewController.handleTapAtPoint(_clickLocation)
            }
        }
        
        super.mouseDown(with: theEvent)
    }
    
    // forward drag event to the view controller as "pan" events
    override func mouseDragged(with theEvent: NSEvent) {
        if theEvent.modifierFlags.contains(.option) {
            let p = self.convert(theEvent.locationInWindow, from: nil)
            _gameViewController.tiltCameraWithOffset(CGPoint(x: p.x - _clickLocation.x, y: p.y - _clickLocation.y))
        } else {
            _gameViewController.handlePanAtPoint(self.convert(theEvent.locationInWindow, from: nil))
        }
        
        super.mouseDragged(with: theEvent)
    }
    
    // forward mouse up events as "end gesture"
    override func mouseUp(with theEvent: NSEvent) {
        _gameViewController.gestureDidEnd()
        super.mouseUp(with: theEvent)
    }
    
}
