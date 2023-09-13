//
//  ConcreteLowLevelNetwork.swift
//  NewbCook
//
//  Created by iury on 9/13/23.
//

import Foundation

public class ConcreteLowLevelNetwork: LowLevelNetworkConnection {
    public init() {}
    public func execute(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = try await URLSession.shared.data(for: request)
        return response
    }
}
