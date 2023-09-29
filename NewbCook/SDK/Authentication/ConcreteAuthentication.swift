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

class ConcreteAuthentication: ObservableObject, Authentication, BackendMessages {
    @Published var authenticationState: AuthenticationState = .checking
    
    static let shared = ConcreteAuthentication()
    var backendMessageType: BackendMessageType = .Authentication
    
    var userSettings: ConcreteUserSettings
    var dataParser: DataParser
    var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()
    
    private init(
        userSettings: ConcreteUserSettings = ConcreteUserSettings.shared,
        dataParser: DataParser = ConcreteDataParser()
    ) {
        self.userSettings = userSettings
        self.dataParser = dataParser
        $authenticationState.sink { state in
            print("State: \(state)")
        }.store(in: &cancellables)
        self.checkAuthenticationState()
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
                let loginUserSettings = LoginUserSettings(
                    username: transmitLoginCredentials.username,
                    hostname: transmitLoginCredentials.hostname,
                    token: authenticationToken.token,
                    refreshToken: authenticationToken.refreshToken,
                    tokenValidated: true
                )
                
                await self.userSettings.loginUser(for: loginUserSettings)
                DispatchQueue.main.async {
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
    
    func checkAuthenticationState() {
        Task {
            // TODO: Make network request to backend to know if token isn't expired
            let tokenValid = await self.userSettings.tokenValidated()
            DispatchQueue.main.async {
                self.authenticationState = tokenValid ? .isAuthenticated : .notAuthenticated
            }
        }
    }
    
    @MainActor
    func invalidateUserCredentials() {
        self.userSettings.clearAllValues()
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

// BackendMessages
extension ConcreteAuthentication {
    typealias MessageType = AuthenticationState
    
    func received(object: AuthenticationState) {
        self.authenticationState = object
    }
    
    func connectionDidClose() {
        self.authenticationState = .notAuthenticated
    }
}
