//
//  SheetView.swift
//  FittedSheetsPod
//
//  Created by Gordon Tucker on 8/5/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

#if os(iOS)
import UIKit

class SheetView: UIView {

    weak var delegate: SheetViewDelegate?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.delegate?.sheetPoint(inside: point, with: event) ?? true
    }
}

#endif // os(iOS)
