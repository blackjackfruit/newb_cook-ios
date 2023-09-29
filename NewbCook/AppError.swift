//
//  AppError.swift
//  NewbCook
//
//  Created by iury on 9/28/23.
//

import Foundation

public enum AppError: Error {
    case hostNotAvailable // When the server is not running
    case invalidCredentials
    case sessionExpired
    case sessionInvalid
    case custom(message: String)
    
    var description: String {
        switch self {
        case .hostNotAvailable:
            return "Check server is running"
        case .invalidCredentials:
            return "Invalid credentials"
        case .sessionExpired:
            return "Session unable to refresh, please log in again"
        case .sessionInvalid:
            return "Session is no longer valid, please re-login"
        case .custom(message: let msg):
            return msg
        }
    }
}
