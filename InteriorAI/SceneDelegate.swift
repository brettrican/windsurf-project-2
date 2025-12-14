//
//  SceneDelegate.swift
//  InteriorAI
//
//  Scene delegate for SwiftUI lifecycle
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Logger.shared.lifecycle("Scene disconnected")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Logger.shared.lifecycle("Scene became active")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        Logger.shared.lifecycle("Scene will resign active")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Logger.shared.lifecycle("Scene will enter foreground")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Logger.shared.lifecycle("Scene entered background")
    }
}
