//
//  NetworkConnection.swift
//  NewbCook
//
//  Created by iury on 8/18/23.
//

import Foundation

public protocol NetworkConnection {
    func executeNetworkCall(for requestBuilder: BackendRequestBuilder) async throws -> Data
}

public class ConcreteNetworkConnection: NetworkConnection {
    
    let secureStorage: SecureStorage
    
    public init(
        secureStorage: SecureStorage = KeychainStorage.shared
    ) {
        self.secureStorage = secureStorage
    }
    
    // All network calls go through this function except for login.
    // If token has expired then refreshing of token will occur, if that fails due to user logged in on another device then
    // this function will return the appropriate error so to have user log back in.
    public func executeNetworkCall(for requestBuilder: BackendRequestBuilder) async throws -> Data {
        let request = try requestBuilder.build()
        guard
            let storedTokenValidated = self.secureStorage.retrieve(key: StorageKey.tokenValidated) as? Bool,
            var token = self.secureStorage.retrieve(key: .token) as? String,
            let refreshToken = self.secureStorage.retrieve(key: .refreshToken) as? String,
            let urlString = request.url,
            let urlMethod = request.httpMethod
        else {
            throw AppError.custom(message: "Internal app error. Should never been reached")
        }
        func attemptTokenRefresh(newTokenURL: URL, saveTokenURL: URL) async throws -> String {
            var getNewTokenRequest = URLRequest(url: newTokenURL)
            getNewTokenRequest.httpMethod = "POST"
            getNewTokenRequest.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
            let (data,response) = try await URLSession.shared.data(for: getNewTokenRequest)
            if let getNewTokenRequestError = process(response: response, data: data) {
                throw getNewTokenRequestError
            }
            guard let authenticationToken = processDataForAuthenticationToken(data: data) else {
                throw AppError.custom(message: "TODO")
            }
            self.secureStorage.save(key: StorageKey.token, value: authenticationToken.token)
            
            var saveNewTokenRequest = URLRequest(url: saveTokenURL)
            saveNewTokenRequest.httpMethod = "PATCH"
            saveNewTokenRequest.setValue("Bearer \(authenticationToken.token)", forHTTPHeaderField: "Authorization")
            let (saveData, saveResponse) = try await URLSession.shared.data(for: saveNewTokenRequest)
            if let saveNewTokenRequestError = process(response: saveResponse, data: saveData) {
                throw saveNewTokenRequestError
            }
            self.secureStorage.save(key: StorageKey.refreshToken, value: authenticationToken.refreshToken)
            self.secureStorage.save(key: StorageKey.tokenValidated, value: true)
            return authenticationToken.token
        }
        
        func clearDataAndLogOut() {
            self.secureStorage.remove(key: StorageKey.token)
            self.secureStorage.remove(key: StorageKey.refreshToken)
            self.secureStorage.remove(key: StorageKey.username)
            self.secureStorage.remove(key: StorageKey.tokenValidated)
        }
        
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let getNewTokenURL = URL(string: "http://\(hostname)/jwt_life_cycle_maintainer_get_new_token"),
            let saveNewTokenURL = URL(string: "http://\(hostname)/jwt_life_cycle_maintainer_save_new_token")
        else {
            throw AppError.custom(message: "TODO") //TODO:
        }
        
        if storedTokenValidated == false {
            token = try await attemptTokenRefresh(newTokenURL: getNewTokenURL, saveTokenURL: saveNewTokenURL)
        }
        let mutableURLRequest = MutableURLRequest(url: urlString)
        mutableURLRequest.httpMethod = urlMethod
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        mutableURLRequest.httpBody = request.httpBody
        
        let (data, response) = try await URLSession.shared.data(for: mutableURLRequest as URLRequest)
        guard var appError = process(response: response, data: data) else {
            return data
        }
        switch appError {
        case .sessionExpired:
            self.secureStorage.save(key: StorageKey.tokenValidated, value: false)
            do {
                token = try await attemptTokenRefresh(newTokenURL: getNewTokenURL, saveTokenURL: saveNewTokenURL)
                mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: mutableURLRequest as URLRequest)
                if let error = process(response: response, data: data) {
                    throw error
                }
                return data
            } catch let error as AppError {
                appError = error
                switch appError{
                case .sessionInvalid:
                    clearDataAndLogOut()
                default:
                    throw error
                }
            } catch let error {
                throw error
            }
        case .sessionInvalid:
            clearDataAndLogOut()
        default:
            throw appError
        }
        
        throw appError
    }
}


extension NetworkConnection {
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
    
    func processDataForAuthenticationToken(data: Data) -> AuthenticationToken? {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if let responseDict = json?["response"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                return try JSONDecoder().decode(AuthenticationToken.self, from: jsonData)
            }
        } catch {
            
        }
        return nil
    }
}
