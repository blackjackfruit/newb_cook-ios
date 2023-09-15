//
//  ConcreteAuthentication.swift
//  NewbCook
//
//  Created by iury on 9/15/23.
//

import Foundation
import Combine

enum AuthenticationState {
    case checking
    case isAuthenticated
    case notAuthenticated
}

class ConcreteAuthentication: ObservableObject, Authentication {
    @Published var authenticationState: AuthenticationState = .checking
    
    static let shared = ConcreteAuthentication()
    
    var storage: Storage
    var dataParser: DataParser
    var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()
    
    init(
        storage: Storage = KeychainStorage.shared,
        dataParser: DataParser = ConcreteDataParser()
    ) {
        self.storage = storage
        self.dataParser = dataParser
        self.listenToAuthenticationChange()
        $authenticationState.sink { state in
            print("State: \(state)")
        }.store(in: &cancellables)
    }
    
    func validateLoginCredentials(using transmitLoginCredentials: TransmitLoginCredentials, completion: @escaping (AppError?)-> Void) {
        Task {
            var appError: AppError = AppError.custom(message: "Unable to handle response")
            do {
                let request = try ConcreteBackendRequestBuilder(endpoint: transmitLoginCredentials).build()
                let (data, response) = try await URLSession.shared.data(for: request) // TODO: Must remove this line for NetworkManager
                if let appError = process(response: response, data: data) {
                    throw appError
                }
                let authenticationToken: AuthenticationToken = try dataParser.decode(data: data)
                DispatchQueue.main.async {
                    self.storage.save(key: StorageKey.hostname, value: transmitLoginCredentials.hostname)
                    self.storage.save(key: StorageKey.username, value: transmitLoginCredentials.username)
                    self.storage.save(key: StorageKey.token, value: authenticationToken.token)
                    self.storage.save(key: StorageKey.refreshToken, value: authenticationToken.refreshToken)
                    self.storage.save(key: StorageKey.tokenValidated, value: true)
                    self.authenticationState = .isAuthenticated
                }
                completion(nil)
            }
            catch let error as AppError {
                appError = error
            }
            catch {
                appError = AppError.custom(message: "Unhandled response")
            }
            completion(appError)
        }
    }
    
    func listenToAuthenticationChange() {
        
        if let tokenValid = self.storage.retrieve(key: StorageKey.tokenValidated) as? Bool {
            self.authenticationState = tokenValid ? .isAuthenticated : .notAuthenticated
            return
        }
        self.authenticationState = .notAuthenticated
                        
        // TODO: Need to not use a timer and start listening to the server push event for authentication state change
//        var invalid = 5
//        Timer.publish(every: 1, on: .current, in: .default).autoconnect().sink { [weak self] _ in
//            guard let self = self else {
//                return
//            }
//            if invalid == 0 {
////                print("Is Not authenticated")
////                self.authenticationState = .notAuthenticated
//            } else {
//                if let tokenValid = self.storage.retrieve(key: StorageKey.tokenValidated) as? Bool {
//                    self.authenticationState = tokenValid ? .isAuthenticated : .notAuthenticated
//                    return
//                }
//                self.authenticationState = .notAuthenticated
//                invalid -= 1
//            }
//
//        }.store(in: &cancellables)
    }
    
    @MainActor
    func invalidateUserCredentials() {
        self.storage.remove(key: StorageKey.tokenValidated)
        self.storage.remove(key: StorageKey.token)
        self.storage.remove(key: StorageKey.refreshToken)
        self.storage.remove(key: StorageKey.username)
        self.authenticationState = .notAuthenticated
    }
    
    func process(response: URLResponse, data: Data) -> AppError? {
        guard let urlResponse = response as? HTTPURLResponse else {
            return AppError.custom(message: "Unable to process response")
        }
        var backendError: BackendError?
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let jsonResponse = json?["response"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonResponse, options: [])
                backendError = try JSONDecoder().decode(BackendError.self, from: jsonData)
            }
        } catch let error {
            print(error)
        }
        switch urlResponse.statusCode {
        case 200:
            fallthrough
        case 201:
            return nil
        case 401:
            if let backendError = backendError {
                switch backendError.reason {
                case .sessionExpired:
                    return AppError.sessionExpired
                default:
                    return .custom(message: "TODO")
                }
            }
            return AppError.invalidCredentials
        default:
            return AppError.custom(message: "Unknown response from server")
        }
    }
}
