//
//  LowLevelNetwork.swift
//  NewbCook
//
//  Created by iury on 9/13/23.
//

import Foundation

public protocol CoreNetwork {
    func execute(for request: URLRequest) async throws -> (Data, URLResponse)
}
