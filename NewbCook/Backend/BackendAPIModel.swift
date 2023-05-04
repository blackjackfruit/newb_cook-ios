//
//  BackendAPIModel.swift
//  NewbCook
//
//  Created by iury on 4/25/23.
//

import Foundation

enum BackendErrorReasons: String, Codable {
    case usernamePasswordInvalid = "username_password_invalid"
    case invalidToken = "invalid_token"
    case invalidTokenMalformed = "invalid_token_malformed"
    case invalidUserId = "invalid_user_id"
    case sessionExpired = "session_expired"
    case sessionInvalid = "session_invalid" // User was logged in but there is no way to get a new access token.
    // default will be UNKNOWN similar to the server
}

struct BackendError: Codable {
    let message: String
    let statusCode: UInt
    let reason: BackendErrorReasons
    
    enum CodingKeys: String, CodingKey {
        case message
        case statusCode = "status_code"
        case reason = "reason"
    }
}
