//
//  LocalNotesApp.swift
//  LocalNotes
//
//  Created by krow on 07-03-23.
//

import SwiftUI

@main
struct LocalNotesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State var isNotAuthenticated = (KeychainStorage.shared.retrieve(key: StorageKey.token) as? String) != nil ? false: true
    
    var body: some Scene {
        WindowGroup {
            MainTabView(isNotAuthenticated: $isNotAuthenticated)
        }
    }
}
