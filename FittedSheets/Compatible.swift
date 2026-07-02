//
//  Compatible.swift
//  FittedSheets
//

#if os(iOS)
import UIKit

extension UIApplication {
    /// The key window across all connected scenes, preferring a foreground-active scene.
    /// Replaces the deprecated `UIApplication.keyWindow` / `UIApplication.windows` key-window scans.
    var fs_keyWindow: UIWindow? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeWindows = scenes.filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
        return activeWindows.first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? activeWindows.first
    }
}

#endif // os(iOS)
