//
//  NetworkManager.swift
//  NewbCook
//
//  Created by iury on 9/13/23.
//

import Foundation

public protocol NetworkManager {
    func execute(for requestBuilder: BackendRequestBuilder, credentials: Credentials) async throws -> (Data, Credentials)
}
