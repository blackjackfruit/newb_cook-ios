//
//  LoginViewModel.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation
import Combine
@MainActor
class LoginViewModel: ObservableObject {
    @Published var hostname: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var allFieldsValid: Bool = false
    @Published var isAuthenticatingUser: Bool = false
    
    let storage: Storage
    var authentication: ConcreteAuthentication
    var cancellables = Set<AnyCancellable>()
    
    init(
        storage: Storage = KeychainStorage.shared,
        authentication: ConcreteAuthentication
    ) {
        self.storage = storage
        self.authentication = authentication
        self.hostname = getLastValidEndpoint() ?? ""
        self.listenToChangesToVars()
    }
    
    func validateUser(completion: @escaping (AppError?) -> Void)
    {
        self.isAuthenticatingUser = true
        let transmitLoginCredentials = ConcreteTransmitLoginCredentials(hostname: hostname, username: username, password: password)
        self.authentication.validateLoginCredentials(using: transmitLoginCredentials) { appError in
            DispatchQueue.main.async {
                self.isAuthenticatingUser = false
                completion(appError)
            }
        }
    }
}

extension LoginViewModel {

    func getLastValidEndpoint() -> String? {
        return storage.retrieve(key: StorageKey.hostname) as? String
    }
    
    func listenToChangesToVars() {
        let isLoginButtonEnabled = Publishers.CombineLatest3($hostname, $username, $password)
        isLoginButtonEnabled.sink { [weak self] obj1, obj2, obj3 in
            if obj1.count > 0 && obj2.count > 0 && obj3.count > 0 {
                self?.allFieldsValid = true
            } else {
                self?.allFieldsValid = false
            }
        }.store(in: &cancellables)
    }
}

extension LoginViewModel {
    convenience init() {
        self.init(storage: KeychainStorage.shared, authentication: ConcreteAuthentication.shared)
    }
}
