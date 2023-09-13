//
//  EndpointAPIs.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation

protocol BackendAPIDelegate: AnyObject {
    // All user data will be cleared before this function is called
    func userNotLoggedIn()
}

enum HTTPMethod {
    case post
    case get
    case patch
    case delete
}

public protocol BackendAPI {
    func fetchToken(using transmitLoginCredentials: TransmitLoginCredentials) async -> Result<AuthenticationToken, AppError>
    func execute<T: TransmitEndpoint & Codable, S: Codable>(item: T) async -> Result<S, AppError>
}

public class ConcreteBackendAPI: ObservableObject, BackendAPI {
    public var hostname: String?
    
    @Published var isAuthenticated = false
    let dataParser: DataParser
    let networkManager: NetworkManager
    static let shared: BackendAPI = ConcreteBackendAPI()
    let secureStorage: Storage
    weak var delegate: BackendAPIDelegate?
    
    
    // TODO: Need to not depend on this variable
    // Need to make sure fetchList returns [] if the function is already attempting to pull in new data
    // or improve the onAppear for getting to the end of a list
    static var isLoadingingOlderData = false
    
    public init(
        secureStorage: Storage = KeychainStorage.shared,
        dataParser: DataParser = ConcreteDataParser(),
        networkManager: NetworkManager = ConcreteNetworkManager()
    ) {
        self.secureStorage = secureStorage
        self.dataParser = dataParser
        self.networkManager = networkManager
    }
    
    public func fetchToken(using transmitLoginCredentials: TransmitLoginCredentials) async -> Result<AuthenticationToken, AppError> {
        var appError: AppError = AppError.custom(message: "Unable to handle response")
        do {
            let request = try ConcreteBackendRequestBuilder(endpoint: transmitLoginCredentials).build()
            let (data, response) = try await URLSession.shared.data(for: request) // TODO: Must remove this line for NetworkManager
            if let appError = process(response: response, data: data) {
                throw appError
            }
            let authenticationToken: AuthenticationToken = try dataParser.decode(data: data)
            self.secureStorage.save(key: StorageKey.hostname, value: transmitLoginCredentials.hostname)
            self.secureStorage.save(key: StorageKey.username, value: transmitLoginCredentials.username)
            self.secureStorage.save(key: StorageKey.token, value: authenticationToken.token)
            self.secureStorage.save(key: StorageKey.refreshToken, value: authenticationToken.refreshToken)
            self.secureStorage.save(key: StorageKey.tokenValidated, value: true)
            return .success(authenticationToken)
        }
        catch let error as AppError {
            appError = error
        }
        catch {
            appError = AppError.custom(message: "Unhandled response")
        }
        return .failure(appError)
    }
    
    public func setHostname(_ hostname: String) {
        self.hostname = hostname
    }
    
    /**
     Execute a network call that conforms to TransmitEndpoint after having authenticated the user. If the user's token has expired then a refresh will occur without the need to call an API.
     */
    public func execute<T: TransmitEndpoint & Codable, S: Codable>(item: T) async -> Result<S, AppError>  {
        guard
            let hostname = self.secureStorage.retrieve(key: StorageKey.hostname) as? String,
            let storedTokenValidated = self.secureStorage.retrieve(key: StorageKey.tokenValidated) as? Bool,
            let token = self.secureStorage.retrieve(key: .token) as? String,
            let refreshToken = self.secureStorage.retrieve(key: .refreshToken) as? String
        else {
            return .failure(AppError.custom(message: "TODO:"))
        }
        let requestBuilder = ConcreteBackendRequestBuilder(hostname: hostname, endpoint: item)
        
        let credentials = Credentials(token: token, refreshToken: refreshToken, tokenValid: storedTokenValidated)
        do {
            let (data, credentials) = try await networkManager.execute(for: requestBuilder, credentials: credentials)
            self.secureStorage.save(key: StorageKey.token, value: credentials.token)
            self.secureStorage.save(key: StorageKey.refreshToken, value: credentials.refreshToken)
            self.secureStorage.save(key: StorageKey.tokenValidated, value: credentials.tokenValid)
            let returnObject: S = try dataParser.decode(data: data)
            return .success(returnObject)
        }
        catch let networkManagerError as NetworkManagerErrors {
            switch networkManagerError {
            case .invalidCredentials:
                clearDataAndLogOut()
            case .sessionExpired:
                self.secureStorage.save(key: StorageKey.tokenValidated, value: false)
            default:
                print("TODO")
            }
            return .failure(AppError.custom(message: "TODO"))
        }
        catch let error {
            self.secureStorage.save(key: StorageKey.token, value: credentials.token)
            return .failure(AppError.custom(message: "TODO: \(error)"))
        }
    }
    
    func clearDataAndLogOut() {
        self.secureStorage.remove(key: StorageKey.token)
        self.secureStorage.remove(key: StorageKey.refreshToken)
        self.secureStorage.remove(key: StorageKey.username)
        self.secureStorage.remove(key: StorageKey.tokenValidated)
    }
}
 
extension ConcreteBackendAPI {
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
