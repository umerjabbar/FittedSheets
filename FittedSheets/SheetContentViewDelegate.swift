//
//  SheetContentViewDelegate.swift
//  FittedSheetsPod
//
//  Created by Gordon Tucker on 7/29/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

#if os(iOS)
import UIKit

@MainActor
protocol SheetContentViewDelegate: AnyObject {
    func preferredHeightChanged(oldHeight: CGFloat, newHeight: CGFloat)
    func pullBarTapped()
}

#endif // os(iOS)
