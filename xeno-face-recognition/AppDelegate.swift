//
//  AppDelegate.swift
//  xeno-face-recognition
//
//  Created by MacOS on 24/02/23.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        let vc = HomeController()
        let nav = UINavigationController(rootViewController: vc)
        window?.rootViewController = nav
        
        return true
    }

}

