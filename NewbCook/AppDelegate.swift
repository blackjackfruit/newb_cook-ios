//
//  AppDelegate.swift
//  LocalNotes
//
//  Created by krow on 10-03-23.
//

import Foundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Application did finish launch")
        let networkManager = ConcreteNetworkManager.shared
        let authentication = ConcreteAuthentication.shared
        networkManager.register(backendMessage: authentication)
        
        return true
    }
}
