//
//  SecureStorage.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation

public enum StorageKey: String, CustomStringConvertible {
    case endpoint = "login.endpoint"
    case token = "login.token"
    case refreshToken = "login.refreshToken"
    case username = "login.username"
    case tokenValidated = "login.tokenValidated" // When a token is received from the server it must be marked as validated else it is not validated

    public var description: String {
        return self.rawValue
    }
}

public protocol SecureStorage {
    func save(key: StorageKey, value: Any)
    func retrieve(key: StorageKey) -> Any?
    func remove(key: StorageKey)
}

public class KeychainStorage: SecureStorage {
    public static let shared = KeychainStorage()
}

#if DEBUG
public extension KeychainStorage {
    var userdefaults: UserDefaults {
        get {
            return UserDefaults.standard
        }
    }
    
    func save(key: StorageKey, value: Any) {
        userdefaults.set(value, forKey: key.rawValue)
    }
    func retrieve(key: StorageKey) -> Any? {
        return userdefaults.object(forKey: key.rawValue)
    }

    func remove(key: StorageKey) {
        userdefaults.set(nil, forKey: key.rawValue)
    }
}
#else
extension KeychainStorage {
    func save(key: String, value: Any) {
        
    }
    
    func retrieve(key: String) -> Any? {
        return ""
    }

    func remove(key: String) {
        
    }
}
#endif
