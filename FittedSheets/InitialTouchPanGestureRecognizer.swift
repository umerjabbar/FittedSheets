//
//  InitialTouchPanGestureRecognizer.swift
//  FittedSheets
//
//  Created by Gordon Tucker on 8/27/18.
//  Copyright © 2018 Gordon Tucker. All rights reserved.
//
#if os(iOS)
import UIKit.UIGestureRecognizerSubclass

class InitialTouchPanGestureRecognizer: UIPanGestureRecognizer {
    var initialTouchLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        // Only record the very first touch of a recognition cycle so a second
        // finger landing before the pan begins can't overwrite the anchor point.
        if state == .possible, initialTouchLocation == nil {
            initialTouchLocation = touches.first?.location(in: view)
        }
    }

    override func reset() {
        super.reset()
        initialTouchLocation = nil
    }
}
#endif
