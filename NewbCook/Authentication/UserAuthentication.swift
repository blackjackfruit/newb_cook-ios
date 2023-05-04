//
//  Authentication.swift
//  LocalNotes
//
//  Created by krow on 08-03-23.
//

import Foundation

class UserAuthentication: ObservableObject {
    
    static let shared = UserAuthentication()
    let secureStorage: SecureStorage
    
    @Published var validationNeeded: Bool
    
    init(secureStorage: SecureStorage = KeychainStorage.shared) {
        self.secureStorage = secureStorage
        self.validationNeeded = ((secureStorage.retrieve(key: .token) as? String) != nil) ? false: true
    }
    
    func retrieveUserToken() -> String? {
        return self.secureStorage.retrieve(key: .token) as? String
    }
    
    func saveUserToken(token: String) {
        self.secureStorage.save(key: .token, value: token)
        self.validationNeeded = false
    }
    
    func removeUserToken() {
        secureStorage.remove(key: .token)
        validationNeeded = false
    }
}
