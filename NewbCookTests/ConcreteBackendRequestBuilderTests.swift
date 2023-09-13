//
//  LocalNotesTests.swift
//  LocalNotesTests
//
//  Created by krow on 07-03-23.
//

import XCTest
@testable import NewbCook

final class ConcreteBackendRequestBuilderTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testConcreteBackendRequestBuilder_build_login_credentials_empty_endpoint_must_fail() throws {
        let endpoint = ConcreteTransmitLoginCredentials(hostname: "", username: "uname1", password: "pword1")
        let builder = ConcreteBackendRequestBuilder(endpoint: endpoint)
        XCTAssertThrowsError(try builder.build())
    }

    func testConcreteBackendRequestBuilder_build_login_credentials() throws {
        let endpoint = ConcreteTransmitLoginCredentials(hostname: "endpoint.com", username: "uname1", password: "pword1")
        let encodedEndpoint = try? JSONEncoder().encode(endpoint)
        let builder = ConcreteBackendRequestBuilder(endpoint: endpoint)
        let urlRequest = try builder.build()
        let decodedEndpoint = try? JSONDecoder().decode(ConcreteTransmitLoginCredentials.self, from: urlRequest.httpBody!)
        
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(urlRequest.httpBody, encodedEndpoint)
        
        XCTAssertEqual(decodedEndpoint?.hostname, endpoint.hostname)
        XCTAssertEqual(decodedEndpoint?.username, endpoint.username)
        XCTAssertEqual(decodedEndpoint?.password, endpoint.password)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
