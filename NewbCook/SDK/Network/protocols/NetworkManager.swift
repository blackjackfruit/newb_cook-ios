//
//  NetworkManager.swift
//  NewbCook
//
//  Created by iury on 9/13/23.
//

import Foundation

public protocol NetworkManager {
    func execute(for requestBuilder: BackendRequestBuilder, credentials: Credentials) -> Task<(Data,Credentials), Error>
    
    // Only one type of BackendMessageType can be registered at any one time
    func register(backendMessage: some BackendMessages)
}
