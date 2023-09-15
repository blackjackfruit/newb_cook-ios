//
//  Authentication.swift
//  LocalNotes
//
//  Created by krow on 08-03-23.
//

import Foundation

class ConcreteUserSettings {
    
    static let shared = ConcreteUserSettings()
    let storage: Storage
    
    init(storage: Storage = KeychainStorage.shared) {
        self.storage = storage
    }
    
    func retrieveUserToken() -> String? {
        return self.storage.retrieve(key: .token) as? String
    }
    
    func saveUserToken(token: String) {
        self.storage.save(key: .token, value: token)
    }
    
    func currentlyConnectedToHost() -> String? {
        return storage.retrieve(key: StorageKey.hostname) as? String
    }
    
    func removeUserToken() {
        storage.remove(key: .token)
    }
}
