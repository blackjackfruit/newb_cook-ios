//
//  ConcreteNetworkManagerTests.swift
//  NewbCookTests
//
//  Created by iury on 9/13/23.
//

import XCTest
@testable import NewbCook

final class ConcreteNetworkManagerTests: XCTestCase {
    override func setUpWithError() throws {
        
    }
    
    override func tearDownWithError() throws {
        
    }
    
    func test_execute_hostname_count_0() async {
        do {
            let requestBuilder = ConcreteBackendRequestBuilder(hostname: "", endpoint: ConcreteTransmitFetchList(listName: "empty"))
            let networkManager = ConcreteNetworkManager()
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
}
