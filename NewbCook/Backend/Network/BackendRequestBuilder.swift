//
//  Parser.swift
//  NewbCook
//
//  Created by iury on 8/18/23.
//

import Foundation

public protocol BackendRequestBuilder {
    var refreshToken: Bool { get }
    func build() throws -> URLRequest
}

class ConcreteBackendRequestBuilder: BackendRequestBuilder {
    var refreshToken: Bool = true
    let secureStorage: SecureStorage
    var transmitEndpoint: (TransmitEndpoint & Codable)?
    var transmitLoginCredentials: TransmitLoginCredentials?
    
    init(
        secureStorage: SecureStorage = KeychainStorage.shared,
        endpoint: TransmitEndpoint & Codable
    ) {
        self.secureStorage = secureStorage
        self.transmitEndpoint = endpoint
    }
    
    init(
        secureStorage: SecureStorage = KeychainStorage.shared,
        endpoint: TransmitLoginCredentials
    ) {
        self.secureStorage = secureStorage
        self.transmitLoginCredentials = endpoint
    }
    
    func refreshToken(_ input: Bool) -> ConcreteBackendRequestBuilder {
        self.refreshToken = input
        return self
    }
}

extension ConcreteBackendRequestBuilder {
    func build() throws -> URLRequest {
        if let endpoint = self.transmitEndpoint {
            return try buildRequestForTransmitEndpoint(endpoint)
        } else if let endpoint = self.transmitLoginCredentials {
            return try buildRequestForTransmitLoginCredentials(endpoint)
        }
        throw AppError.custom(message: "TODO")
    }
}

extension ConcreteBackendRequestBuilder {
    func buildRequestForTransmitLoginCredentials(_ endpoint: TransmitLoginCredentials) throws -> URLRequest {
        guard let url = URL(string: "http://\(endpoint.hostName)/\(endpoint.endpoint)") else {
            throw AppError.custom(message: "TODO")
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var appError: AppError = AppError.custom(message: "Unable to handle response")
        do {
            request.httpBody = try JSONEncoder().encode(endpoint)
            request.timeoutInterval = 15
        } catch {
            throw appError
        }
        return request
    }
    
    func buildRequestForTransmitEndpoint(_ transmitEndpoint: TransmitEndpoint & Codable) throws -> URLRequest {
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            var url = URL(string: "http://\(hostname)/\(transmitEndpoint.endpoint)")
        else {
            throw AppError.custom(message: "TODO") //TODO:
        }
        if transmitEndpoint.appendVariablesToRequest, let newURL = createURLRequest(baseURL: "http://\(hostname)/\(transmitEndpoint.endpoint)", object: transmitEndpoint) {
            url = newURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = transmitEndpoint.httpMethod
        if
            type(of: transmitEndpoint) != TransmitLoginCredentials.self
        {
            guard let token = self.secureStorage.retrieve(key: .token) as? String else {
                throw AppError.custom(message: "TODO")
            }
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 5
        
        do {
            if transmitEndpoint.httpMethod == "POST" {
                request.httpBody = try JSONEncoder().encode(transmitEndpoint)
            }
        } catch let error {
            print("Failure \(error)")// TODO: Return error
            throw AppError.custom(message: "TODO")
        }
        
        return request
    }
    
    func createURLRequest(baseURL: String, object: Codable) -> URL? {
        let jsonEncoder = JSONEncoder()
        var urlComponents = URLComponents(string: baseURL)
        do {
            let encodedData = try jsonEncoder.encode(object)
            guard let jsonObject = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any] else {
                return nil
            }
            var queryItems: [URLQueryItem] = []
            for (key, value) in jsonObject {
                if let stringValue = value as? String {
                    queryItems.append(URLQueryItem(name: key, value: stringValue))
                } else if let numberValue = value as? NSNumber {
                    queryItems.append(URLQueryItem(name: key, value: numberValue.stringValue))
                } else if let boolValue = value as? Bool {
                    queryItems.append(URLQueryItem(name: key, value: boolValue ? "true": "false"))
                }
            }
            urlComponents?.queryItems = queryItems
            return urlComponents?.url
        } catch {
            return nil
        }
    }
}
