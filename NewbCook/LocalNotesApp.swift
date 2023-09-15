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

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
