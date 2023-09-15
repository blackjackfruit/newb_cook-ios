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
    
    func backendEndpoint() -> String? {
        guard
            let urlString = concreteUserSettings.currentlyConnectedToHost()
        else {
            return nil
        }
        return urlString
    }

    func logout(completion: @escaping () -> Void) {
        concreteUserSettings.removeUserToken()
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
