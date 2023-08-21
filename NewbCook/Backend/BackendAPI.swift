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
    @Published var isAuthenticated = false
    let dataParser: DataParser
    let networkConnection: NetworkConnection
    static let shared: BackendAPI = ConcreteBackendAPI()
    let secureStorage: SecureStorage
    weak var delegate: BackendAPIDelegate?
    
    // TODO: Need to not depend on this variable
    // Need to make sure fetchList returns [] if the function is already attempting to pull in new data
    // or improve the onAppear for getting to the end of a list
    static var isLoadingingOlderData = false
    
    public init(
        secureStorage: SecureStorage = KeychainStorage.shared,
        dataParser: DataParser = ConcreteDataParser(),
        networkConnection: NetworkConnection = ConcreteNetworkConnection()
    ) {
        self.secureStorage = secureStorage
        self.dataParser = dataParser
        self.networkConnection = networkConnection
    }
    
    public func fetchToken(using transmitLoginCredentials: TransmitLoginCredentials) async -> Result<AuthenticationToken, AppError> {
        var appError: AppError = AppError.custom(message: "Unable to handle response")
        do {
            let request = try ConcreteBackendRequestBuilder(endpoint: transmitLoginCredentials).build()
            let (data, response) = try await URLSession.shared.data(for: request)
            if let appError = process(response: response, data: data) {
                throw appError
            }
            let authenticationToken: AuthenticationToken = try dataParser.decode(data: data)
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
    
    /**
     Execute a network call that conforms to TransmitEndpoint after having authenticated the user. If the user's token has expired then a refresh will occur without the need to call an API.
     */
    public func execute<T: TransmitEndpoint & Codable, S: Codable>(item: T) async -> Result<S, AppError>  {
        let requestBuilder = ConcreteBackendRequestBuilder(endpoint: item)
        do {
            let data = try await networkConnection.executeNetworkCall(for: requestBuilder)
            let returnObject: S = try dataParser.decode(data: data)
            return .success(returnObject)
        } catch let error {
            return .failure(AppError.custom(message: "TODO: \(error)"))
        }
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
