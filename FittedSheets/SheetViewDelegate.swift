//
//  SheetViewDelegate.swift
//  FittedSheetsPod
//
//  Created by Gordon Tucker on 8/5/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

#if os(iOS)
import UIKit

@MainActor
protocol SheetViewDelegate: AnyObject {
    func sheetPoint(inside point: CGPoint, with event: UIEvent?) -> Bool
}

#endif // os(iOS)
