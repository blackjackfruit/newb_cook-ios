//
//  SettingsViewModel.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation


struct SettingsViewModel {
    
    var userAuthentication: UserAuthentication = UserAuthentication()
    
    func backendEndpoint() -> String? {
        guard
            let urlString = secureStorage.retrieve(key: StorageKey.endpoint) as? String
        else {
            return nil
        }
        return urlString
    }

    func logout(completion: @escaping () -> Void) {
        userAuthentication.removeUserToken()
        completion()
    }
}

extension SettingsViewModel {
    var secureStorage: SecureStorage {
        get {
            return KeychainStorage.shared
        }
    }
}
