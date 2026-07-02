//
//  SheetDockSize.swift
//  FittedSheets
//
//  Created by Gordon Tucker on 8/27/18.
//  Copyright © 2018 Gordon Tucker. All rights reserved.
//

#if os(iOS)
import CoreGraphics

public enum SheetSize: Equatable, Sendable {
    case intrinsic
    case fixed(CGFloat)
    case fullscreen
    case percent(CGFloat)
    case marginFromTop(CGFloat)
}

#endif // os(iOS)
