// swift-tools-version: 6.0
//
//  Package.swift
//  FittedSheets
//
//  Created by Andrew Breckenridge on 6/18/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "FittedSheets",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "FittedSheets", targets: ["FittedSheets"]),
    ],
    targets: [
        .target(name: "FittedSheets", path: "FittedSheets"),
    ],
    swiftLanguageModes: [.v6]
)
