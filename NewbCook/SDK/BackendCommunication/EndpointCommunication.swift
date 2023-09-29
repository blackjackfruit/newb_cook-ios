//
//  EndpointAPIs.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation

enum HTTPMethod {
    case post
    case get
    case patch
    case delete
}

public protocol EndpointCommunication {
    func execute<T: TransmitEndpoint & Codable, S: Codable>(item: T) async -> Result<S, AppError>
}

public class ConcreteEndpointCommunication: ObservableObject, EndpointCommunication {
    public var hostname: String?
    
    @Published var isAuthenticated = false
    let dataParser: DataParser
    let networkManager: NetworkManager
    static let shared: EndpointCommunication = ConcreteEndpointCommunication()
    let storage: Storage
    
    
    // TODO: Need to not depend on this variable
    // Need to make sure fetchList returns [] if the function is already attempting to pull in new data
    // or improve the onAppear for getting to the end of a list
    static var isLoadingingOlderData = false
    
    private init(
        storage: Storage = KeychainStorage.shared,
        dataParser: DataParser = ConcreteDataParser(),
        networkManager: NetworkManager = ConcreteNetworkManager.shared
    ) {
        self.storage = storage
        self.dataParser = dataParser
        self.networkManager = networkManager
    }
    
    public func setHostname(_ hostname: String) {
        self.hostname = hostname
    }
    
    /**
     Execute a network call that conforms to TransmitEndpoint after having authenticated the user. If the user's token has expired then a refresh will occur without the need to call an API.
     */
    public func execute<T: TransmitEndpoint & Codable, S: Codable>(item: T) async -> Result<S, AppError>  {
        guard
            let hostname = self.storage.retrieve(key: StorageKey.hostname) as? String,
            let storedTokenValidated = self.storage.retrieve(key: StorageKey.tokenValidated) as? Bool,
            let token = self.storage.retrieve(key: .token) as? String,
            let refreshToken = self.storage.retrieve(key: .refreshToken) as? String
        else {
            return .failure(AppError.custom(message: "TODO:"))
        }
        
        let requestBuilder = ConcreteBackendRequestBuilder(hostname: hostname, endpoint: item)
        let credentials = Credentials(token: token, refreshToken: refreshToken, tokenValid: storedTokenValidated)
        
        do {
            let (data, credentials) = try await networkManager.execute(for: requestBuilder, credentials: credentials)
            self.storage.save(key: StorageKey.token, value: credentials.token)
            self.storage.save(key: StorageKey.refreshToken, value: credentials.refreshToken)
            self.storage.save(key: StorageKey.tokenValidated, value: credentials.tokenValid)
            let returnObject: S = try dataParser.decode(data: data)
            return .success(returnObject)
        }
        catch let networkManagerError as NetworkManagerErrors {
            switch networkManagerError {
            case .invalidCredentials:
                clearDataAndLogOut()
            case .sessionExpired:
                self.storage.save(key: StorageKey.tokenValidated, value: false)
            default:
                print("TODO")
            }
            return .failure(AppError.custom(message: "TODO"))
        }
        catch let error {
            self.storage.save(key: StorageKey.token, value: credentials.token)
            return .failure(AppError.custom(message: "TODO: \(error)"))
        }
    }
    
    func clearDataAndLogOut() {
        self.storage.remove(key: StorageKey.token)
        self.storage.remove(key: StorageKey.refreshToken)
        self.storage.remove(key: StorageKey.username)
        self.storage.remove(key: StorageKey.tokenValidated)
    }
}
 
extension ConcreteEndpointCommunication {
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
