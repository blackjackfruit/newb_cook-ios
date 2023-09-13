//
//  LoginViewModel.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation

class LoginViewModel {
    
    let storage: Storage
    var backendAPI: BackendAPI
    
    init(
        storage: Storage,
        backendAPI: BackendAPI
    ) {
        self.storage = storage
        self.backendAPI = backendAPI
    }
    
    func getLastValidEndpoint() -> String? {
        return storage.retrieve(key: StorageKey.hostname) as? String
    }
    
    func validateUser(
        hostname: String,
        username: String,
        password: String) async -> Result<AuthenticationToken, AppError>
    {
        let transmitLoginCredentials = ConcreteTransmitLoginCredentials(hostname: hostname, username: username, password: password)
        let result: Result<AuthenticationToken, AppError> = await self.backendAPI.fetchToken(using: transmitLoginCredentials)
        switch result {
        case .success(let authenticationToken):
            return .success(authenticationToken)
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension LoginViewModel {
    convenience init() {
        self.init(storage: KeychainStorage.shared, backendAPI: ConcreteBackendAPI())
    }
}
