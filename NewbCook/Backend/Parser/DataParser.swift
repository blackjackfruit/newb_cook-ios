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

public class ConcreteDataParser: DataParser {
    
    public init() { }
    
    public func decode<S: Codable>(data: Data) throws -> S {
        let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
        let jsonData = try JSONSerialization.data(withJSONObject: json?["response"] as Any , options: [])
        let object = try JSONDecoder().decode(S.self, from: jsonData)
        return object
    }
}
