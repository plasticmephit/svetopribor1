//
//  AppDelegate.swift
//  svetopribor
//
//  Created by Maksimilian on 5.02.23.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    
    var window: UIWindow?
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()
        
        
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
       
      
        return true
    }




}

