//
//  SceneDelegate.swift
//  FittedSheets
//
//  Adopts the UIScene life cycle required by the iOS 13+ SDK (see TN3187).
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        window.rootViewController = storyboard.instantiateInitialViewController()
        self.window = window
        window.makeKeyAndVisible()

        // Optional: jump straight into a demo when FS_AUTO_OPEN_DEMO names one (testing aid).
        DemoRegistry.autoOpenIfRequested(in: window)
    }
}
