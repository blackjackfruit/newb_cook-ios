//
//  DataParser.swift
//  NewbCook
//
//  Created by iury on 8/20/23.
//

import Foundation

public protocol DataParser {
    func decode<S: Codable>(data: Data) throws -> S
}
