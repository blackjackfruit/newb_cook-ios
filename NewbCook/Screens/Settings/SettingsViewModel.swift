//
//  SettingsViewModel.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation

class SettingsViewModel {
    
    var concreteUserSettings: ConcreteUserSettings
    
    init(userAuthentication: ConcreteUserSettings = ConcreteUserSettings.shared) {
        self.concreteUserSettings = userAuthentication
    }
    
    @MainActor
    func backendEndpoint() -> String? {
        guard
            let urlString = concreteUserSettings.connectedToEndpoint()
        else {
            return nil
        }
        return urlString
    }

    @MainActor
    func logout(completion: @escaping () -> Void) {
        concreteUserSettings.clearAllValues()
        completion()
    }
}

extension SettingsViewModel {
    var storage: Storage {
        get {
            return KeychainStorage.shared
        }
    }
}
