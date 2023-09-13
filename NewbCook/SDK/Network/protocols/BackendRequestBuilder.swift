//
//  Parser.swift
//  NewbCook
//
//  Created by iury on 8/18/23.
//

import Foundation

public protocol BackendRequestBuilder {
    var hostname: String { get }
    var refreshToken: Bool { get }
    func build() throws -> URLRequest
}
