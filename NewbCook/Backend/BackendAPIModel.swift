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

public protocol TransmitEndpoint {

    // If the properties of the object needs to be added to the url parameter, set to true
    var appendVariablesToRequest: Bool { get }
    var httpMethod: String { get }
    var endpoint: String { get }
}

protocol TransmitFetchList: Codable, TransmitEndpoint {
    var listName: String { get }
}

public protocol TransmitLoginCredentials: Codable, TransmitEndpoint {
    var hostName: String { get }
    var username: String { get }
    var password: String { get }
}

protocol TransmitUpdateItem: Codable, TransmitEndpoint {
    var listID: UInt { get }
    var listName: String { get }
    var entryID: UInt { get }
    var entryName: String { get }
    var entryIsCheckMarked: Bool { get }
}

protocol TransmitAddItemToList: Codable, TransmitEndpoint {
    var id: UInt? { get }
    var listName: String { get }
    var entryName: String { get }
}

struct ConcreteTransmitAddItemToList: TransmitAddItemToList {
    let id: UInt?
    let listName: String
    let entryName: String
    let appendVariablesToRequest: Bool = false
    let httpMethod: String = "POST"
    let endpoint: String = "add_new_item_to_list"

    private enum CodingKeys: String, CodingKey {
        case id
        case listName = "list_name"
        case entryName = "entry_name"
    }
}

struct ConcreteTransmitUpdateItem: TransmitUpdateItem {
    let listID: UInt
    let listName: String
    let entryID: UInt
    let entryName: String
    let entryIsCheckMarked: Bool
    let appendVariablesToRequest: Bool = true
    let httpMethod: String = "PATCH"
    let endpoint: String = "update_list_entry_values"
    
    private enum CodingKeys: String, CodingKey {
        case listID = "list_id"
        case listName = "list_name"
        case entryID = "entry_id"
        case entryName = "entry_name"
        case entryIsCheckMarked = "entry_is_check_marked"
    }
}

struct ConcreteTransmitLoginCredentials: TransmitLoginCredentials {
    let hostName: String
    let username: String
    let password: String
    let appendVariablesToRequest: Bool = false
    let httpMethod: String = "POST"
    let endpoint: String = "login"
}

struct ConcreteTransmitSearchRequest: Codable, TransmitEndpoint {
    let searchRequest: String
    let listName: String
    let appendVariablesToRequest: Bool = true
    let httpMethod: String = "GET"
    let endpoint: String = "find_items_for_user"
    
    private enum CodingKeys: String, CodingKey {
        case searchRequest = "search_request"
        case listName = "list_name"
    }
}

struct ConcreteTransmitFetchList: TransmitFetchList {
    var listName: String
    var appendVariablesToRequest: Bool = true
    var httpMethod: String = "GET"
    var endpoint: String = "retrieve_list"
    
    private enum CodingKeys: String, CodingKey {
        case listName = "list_name"
    }
}

struct ConcreteTransmitFetchListsWithIDs: Codable, TransmitEndpoint {
    var appendVariablesToRequest: Bool = false
    var httpMethod: String = "GET"
    var endpoint: String = "retrieve_list_names"
}

struct ConcreteTransmitDeleteList: Codable, TransmitEndpoint {
    let listName: String
    var appendVariablesToRequest: Bool = false
    var httpMethod: String = "POST"
    var endpoint: String = "return_remaining_lists_after_removal_of_list_name"
    
    private enum CodingKeys: String, CodingKey {
        case listName = "list_name"
    }
}

struct ConcreteTransmitCreateNewList: Codable, TransmitEndpoint {
    let listName: String
    var appendVariablesToRequest: Bool = false
    var httpMethod: String = "POST"
    var endpoint: String = "create_new_list"
    
    private enum CodingKeys: String, CodingKey {
        case listName = "list_name"
    }
}

struct ConcreteTransmitDeleteItem: Codable, TransmitEndpoint {
    var entryID: UInt
    var appendVariablesToRequest: Bool = true
    var httpMethod: String = "DELETE"
    var endpoint: String = "delete_entry"
    private enum CodingKeys: String, CodingKey {
        case entryID = "entry_id"
    }
}
