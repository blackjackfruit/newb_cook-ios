//
//  LoginViewModel.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation

class LoginViewModel {
    
    let secureStorage: SecureStorage
    let backendAPI: BackendAPI
    
    init(
        secureStorage: SecureStorage,
        backendAPI: BackendAPI
    ) {
        self.secureStorage = secureStorage
        self.backendAPI = backendAPI
    }
    
    func getLastValidEndpoint() -> String? {
        return secureStorage.retrieve(key: StorageKey.endpoint) as? String
    }
    
    func validateUser(
        hostname: String,
        username: String,
        password: String) async -> Result<AuthenticationToken, AppError>
    {
        let transmitLoginCredentials = ConcreteTransmitLoginCredentials(hostName: hostname, username: username, password: password)
        let result: Result<AuthenticationToken, AppError> = await self.backendAPI.fetchToken(using: transmitLoginCredentials)
        switch result {
        case .success(let authenticationToken):
            self.secureStorage.save(key: StorageKey.endpoint, value: hostname)
            self.secureStorage.save(key: StorageKey.username, value: username)
            self.secureStorage.save(key: StorageKey.token, value: authenticationToken.token)
            self.secureStorage.save(key: StorageKey.refreshToken, value: authenticationToken.refreshToken)
            self.secureStorage.save(key: StorageKey.tokenValidated, value: true)
            return .success(authenticationToken)
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension LoginViewModel {
    convenience init() {
        self.init(secureStorage: KeychainStorage.shared, backendAPI: ConcreteBackendAPI())
    }
}
