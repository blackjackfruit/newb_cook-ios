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
            let urlString = storage.retrieve(key: StorageKey.hostname) as? String
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
    var storage: Storage {
        get {
            return KeychainStorage.shared
        }
    }
}
