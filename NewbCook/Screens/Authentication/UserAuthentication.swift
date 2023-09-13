//
//  Authentication.swift
//  LocalNotes
//
//  Created by krow on 08-03-23.
//

import Foundation

class UserAuthentication: ObservableObject {
    
    static let shared = UserAuthentication()
    let storage: Storage
    
    @Published var validationNeeded: Bool
    
    init(storage: Storage = KeychainStorage.shared) {
        self.storage = storage
        self.validationNeeded = ((storage.retrieve(key: .token) as? String) != nil) ? false: true
    }
    
    func retrieveUserToken() -> String? {
        return self.storage.retrieve(key: .token) as? String
    }
    
    func saveUserToken(token: String) {
        self.storage.save(key: .token, value: token)
        self.validationNeeded = false
    }
    
    func removeUserToken() {
        storage.remove(key: .token)
        validationNeeded = false
    }
}
