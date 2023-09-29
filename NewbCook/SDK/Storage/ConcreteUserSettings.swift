//
//  Authentication.swift
//  LocalNotes
//
//  Created by krow on 08-03-23.
//

import Foundation

struct LoginUserSettings {
    var username: String
    var hostname: String
    var token: String
    var refreshToken: String
    var tokenValidated: Bool
}

@MainActor
class ConcreteUserSettings {
    
    static let shared = ConcreteUserSettings()
    let storage: Storage
    
    private init(storage: Storage = KeychainStorage.shared) {
        self.storage = storage
    }
    
    func loginUser(for settings: LoginUserSettings) {
        self.storage.save(key: StorageKey.hostname, value: settings.hostname)
        self.storage.save(key: StorageKey.username, value: settings.username)
        self.storage.save(key: StorageKey.token, value: settings.token)
        self.storage.save(key: StorageKey.refreshToken, value: settings.refreshToken)
        self.storage.save(key: StorageKey.tokenValidated, value: settings.tokenValidated)
    }
    
    func retrieveUserToken() -> String? {
        return self.storage.retrieve(key: .token) as? String
    }
    
    func saveUserToken(token: String) {
        self.storage.save(key: .token, value: token)
    }
    
    func connectedToEndpoint() -> String? {
        return storage.retrieve(key: StorageKey.hostname) as? String
    }
    
    func tokenValidated() -> Bool {
        return self.storage.retrieve(key: .tokenValidated) as? Bool ?? false
    }
    
    func clearAllValues() {
        self.storage.remove(key: StorageKey.hostname)
        self.storage.remove(key: StorageKey.username)
        self.storage.remove(key: StorageKey.token)
        self.storage.remove(key: StorageKey.refreshToken)
        self.storage.remove(key: StorageKey.tokenValidated)
    }
}
