//
//  ConcreteNetworkManagerTests.swift
//  NewbCookTests
//
//  Created by iury on 9/13/23.
//

import XCTest
@testable import NewbCook

class MockLowLevelNetworkConnection: CoreNetwork {
    private var dummyValue: (Data, URLResponse)?
    private var throwsValue: Error?
    
    struct InternalErrpr: Error {
        
    }
    init() {
    }

    @discardableResult
    func setResponse(_ value: (Data, URLResponse)) -> Self {
        dummyValue = value
        return self
    }

    @discardableResult
    func setThrows(_ value: Error) -> Self {
        throwsValue = value
        return self
    }
    
    func execute(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let dummyValue = dummyValue {
            return dummyValue
        } else if let error = throwsValue {
            throw error
        }
        throw InternalErrpr()
    }
}

final class ConcreteNetworkManagerTests: XCTestCase {
    
    let mockStorage: Storage = KeychainStorage.shared
    let mockNetwork = MockLowLevelNetworkConnection()
    let mockCredentials = Credentials(token: "validtoken", refreshToken: "refreshtoken", tokenValid: true)
    let hostname = "https://localhost:3000"
    
    override func setUpWithError() throws {
        
    }
    
    override func tearDownWithError() throws {
        
    }
    
    func test_execute_hostname_count_0() async {
        do {
            let requestBuilder = ConcreteBackendRequestBuilder(hostname: "", endpoint: ConcreteTransmitFetchList(listName: "empty"))
            let networkManager = ConcreteNetworkManager.shared
            _ = try await networkManager.execute(
                for: requestBuilder,
                credentials: Credentials(token: "", refreshToken: "", tokenValid: true)
            )
        } catch let error as NetworkManagerErrors {
            switch error {
            case .badURL:
                print("good")
            default:
                XCTFail("Should not have been reached")
            }
        } catch {
            XCTFail("Should not have been reached: \(error)")
        }
    }
    
    func test_making_network_call_returns_200_with_mock_data_and_credentials() async {
        do {
            mockStorage.save(key: .token, value: "01234")
            let requestBuilder = ConcreteBackendRequestBuilder(
                hostname: hostname,
                endpoint: ConcreteTransmitFetchList(listName: "empty")
            )
            let tuple: (Data, URLResponse) = (
                try! JSONSerialization.data(withJSONObject: ["test":"passed"]),
                HTTPURLResponse(url: URL(string: hostname)!, statusCode: 200, httpVersion: nil, headerFields: [:])!
            )
            
            mockNetwork.setResponse(tuple)
            let networkManager = ConcreteNetworkManager(lowLevelNetworkConnection: mockNetwork)
            let task = networkManager.execute(
                for: requestBuilder,
                credentials: mockCredentials
            )
            let result = try await task.value
            XCTAssertEqual(tuple.0, result.0)
            XCTAssertEqual(mockCredentials, result.1)
        } catch {
            XCTFail("Should not have been reached: \(error)")
        }
    }
}
