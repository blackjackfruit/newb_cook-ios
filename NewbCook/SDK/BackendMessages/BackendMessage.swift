//
//  BackendMessage.swift
//  NewbCook
//
//  Created by iury on 9/21/23.
//

import Foundation

public enum BackendMessageType {
    case Authentication
    case ListChange
}

public protocol BackendMessages {
    associatedtype MessageType
    var backendMessageType: BackendMessageType { get }
    
    func connectionDidOpen()
    func received(object: MessageType)
    func connectionDidClose()
    func backendMessageFailure(_ error: Error)
}

public extension BackendMessages {
    func connectionDidOpen() {}
    func received(object: MessageType){}
    func connectionDidClose() {}
    func backendMessageFailure(_ error: Error) {}
}
