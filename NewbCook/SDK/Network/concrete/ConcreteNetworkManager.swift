//
//  ConcreteNetworkManager.swift
//  NewbCook
//
//  Created by iury on 8/18/23.
//

import Foundation

public struct Credentials: Equatable {
    let token: String
    let refreshToken: String
    let tokenValid: Bool
}

public enum NetworkManagerErrors: Error {
    case badURL
    case sessionExpired
    case invalidCredentials
    case urlResponseFailedToProcess
    case unknown
}

public class ConcreteNetworkManager: NetworkManager {
    
    let lowLevelNetworkConnection: CoreNetwork
    var backendMessages: [BackendMessageType: any BackendMessages] = [:]
    public static let shared = ConcreteNetworkManager()
#if TEST
    init(lowLevelNetworkConnection: CoreNetwork = ConcreteLowLevelNetwork()) {
        self.lowLevelNetworkConnection = lowLevelNetworkConnection
    }
#else
    private init(
        lowLevelNetworkConnection: CoreNetwork = ConcreteLowLevelNetwork()
    ) {
        self.lowLevelNetworkConnection = lowLevelNetworkConnection
    }
#endif
    
    // All network calls go through this function except for login.
    // If token has expired then refreshing of token will occur, if that fails due to user logged in on another device then
    // this function will return the appropriate error so to have user log back in.
    public func execute(for requestBuilder: BackendRequestBuilder, credentials: Credentials) async throws -> (Data, Credentials) {
        let request = try requestBuilder.build()
        let hostname = requestBuilder.hostname
        var token = credentials.token
        let refreshToken = credentials.refreshToken
        guard
            hostname.count > 0,
            let urlString = request.url,
            let urlMethod = request.httpMethod,
            let getNewTokenURL = URL(string: "http://\(hostname)/jwt_life_cycle_maintainer_get_new_token"),
            let saveNewTokenURL = URL(string: "http://\(hostname)/jwt_life_cycle_maintainer_save_new_token")
        else {
            throw NetworkManagerErrors.badURL
        }
        
        if credentials.tokenValid == false {
            token = try await attemptTokenRefresh(newTokenURL: getNewTokenURL, refreshToken: refreshToken, saveTokenURL: saveNewTokenURL)
        }
        
        let mutableURLRequest = MutableURLRequest(url: urlString)
        mutableURLRequest.httpMethod = urlMethod
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        mutableURLRequest.httpBody = request.httpBody
        
        let (data, response) = try await lowLevelNetworkConnection.execute(for: mutableURLRequest as URLRequest)
        guard let appError = process(response: response, data: data) else {
            return (data, Credentials(token: token, refreshToken: refreshToken, tokenValid: true))
        }
        switch appError {
        case .sessionExpired:
            do {
                token = try await attemptTokenRefresh(newTokenURL: getNewTokenURL, refreshToken: refreshToken, saveTokenURL: saveNewTokenURL)
                mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await lowLevelNetworkConnection.execute(for: mutableURLRequest as URLRequest)
                if let error = process(response: response, data: data) {
                    throw error
                }
                return (data, Credentials(token: token, refreshToken: refreshToken, tokenValid: true))
            } catch let error as NetworkManagerErrors {
                throw error
            } catch let error {
                throw error
            }
        case .invalidCredentials:
            throw appError
        default:
            throw appError
        }
    }

    public func register(backendMessage: some BackendMessages) {
        print(backendMessage.backendMessageType)
        backendMessages[backendMessage.backendMessageType] = backendMessage
    }
}


extension ConcreteNetworkManager {
    func attemptTokenRefresh(newTokenURL: URL, refreshToken: String, saveTokenURL: URL) async throws -> String {
        var getNewTokenRequest = URLRequest(url: newTokenURL)
        getNewTokenRequest.httpMethod = "POST"
        getNewTokenRequest.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
        let (data,response) = try await lowLevelNetworkConnection.execute(for: getNewTokenRequest)
        if let getNewTokenRequestError = process(response: response, data: data) {
            throw getNewTokenRequestError
        }
        guard let authenticationToken = processDataForAuthenticationToken(data: data) else {
            throw AppError.custom(message: "TODO")
        }
        
        var saveNewTokenRequest = URLRequest(url: saveTokenURL)
        saveNewTokenRequest.httpMethod = "PATCH"
        saveNewTokenRequest.setValue("Bearer \(authenticationToken.token)", forHTTPHeaderField: "Authorization")
        let (saveData, saveResponse) = try await lowLevelNetworkConnection.execute(for: saveNewTokenRequest)
        if let saveNewTokenRequestError = process(response: saveResponse, data: saveData) {
            throw saveNewTokenRequestError
        }
        return authenticationToken.token
    }

    func process(response: URLResponse, data: Data) -> NetworkManagerErrors? {
        guard let urlResponse = response as? HTTPURLResponse else {
            return NetworkManagerErrors.urlResponseFailedToProcess
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
                case BackendErrorReasons.sessionExpired:
                    return NetworkManagerErrors.sessionExpired
                default:
                    return NetworkManagerErrors.unknown
                }
            }
            return NetworkManagerErrors.invalidCredentials
        default:
            return NetworkManagerErrors.unknown
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
