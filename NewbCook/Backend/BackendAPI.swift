//
//  EndpointAPIs.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation

enum GenericError: Error {
    case everything // TODO: Must create a proper errors for this class
}

protocol BackendAPIDelegate: AnyObject {
    // All user data will be cleared before this function is called
    func userNotLoggedIn()
}

enum HTTPMethod {
    case post
    case get
    case patch
    case delete
}

enum Endpoints {
    case addNewItemToList
    case createNewList
    case deleteEntry
    case findItemsForUser
    case retrieveListNames
    case retrieveList
    case returnRemainingListsAfterRemovalOfListName
    case updateListEntryValues
}

class BackendAPI: ObservableObject {
    @Published var isAuthenticated = false
    
    static let shared = BackendAPI()
    let secureStorage: SecureStorage
    weak var delegate: BackendAPIDelegate?
    
    // TODO: Need to not depend on this variable
    // Need to make sure fetchList returns [] if the function is already attempting to pull in new data
    // or improve the onAppear for getting to the end of a list
    static var isLoadingingOlderData = false
    
    init(secureStorage: SecureStorage = KeychainStorage.shared) {
        self.secureStorage = secureStorage
    }
    
    func process(response: URLResponse, data: Data) -> AppError? {
        guard let urlResponse = response as? HTTPURLResponse else {
            return AppError.custom(message: "Unable to process response")
        }
        var backendError: BackendError?
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let jsonResponse = json?["response"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonResponse, options: [])
                backendError = try JSONDecoder().decode(BackendError.self, from: jsonData)
            }
        } catch let error {
            print(error)
        }
        switch urlResponse.statusCode {
        case 200:
            fallthrough
        case 201:
            return nil
        case 401:
            if let backendError = backendError {
                switch backendError.reason {
                case .sessionExpired:
                    return AppError.sessionExpired
                default:
                    return .custom(message: "TODO")
                }
            }
            return AppError.invalidCredentials
        default:
            return AppError.custom(message: "Unknown response from server")
        }
    }
    
    // All network calls go through this function except for login.
    // If token has expired then refreshing of token will occur, if that fails due to user logged in on another device then
    // this function will return the appropriate error so to have user log back in.
    func executeNetworkCall(for request: URLRequest) async throws -> Data {
        guard
            let storedTokenValidated = self.secureStorage.retrieve(key: StorageKey.tokenValidated) as? Bool,
            var token = self.secureStorage.retrieve(key: .token) as? String,
            let refreshToken = self.secureStorage.retrieve(key: .refreshToken) as? String,
            let urlString = request.url,
            let urlMethod = request.httpMethod
        else {
            throw AppError.custom(message: "Internal app error. Should never been reached")
        }
        func attemptTokenRefresh(newTokenURL: URL, saveTokenURL: URL) async throws -> String {
            var getNewTokenRequest = URLRequest(url: newTokenURL)
            getNewTokenRequest.httpMethod = "POST"
            getNewTokenRequest.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
            let (data,response) = try await URLSession.shared.data(for: getNewTokenRequest)
            if let getNewTokenRequestError = process(response: response, data: data) {
                throw getNewTokenRequestError
            }
            guard let authenticationToken = processDataForAuthenticationToken(data: data) else {
                throw AppError.custom(message: "TODO")
            }
            self.secureStorage.save(key: StorageKey.token, value: authenticationToken.token)
            
            var saveNewTokenRequest = URLRequest(url: saveTokenURL)
            saveNewTokenRequest.httpMethod = "PATCH"
            saveNewTokenRequest.setValue("Bearer \(authenticationToken.token)", forHTTPHeaderField: "Authorization")
            let (saveData, saveResponse) = try await URLSession.shared.data(for: saveNewTokenRequest)
            if let saveNewTokenRequestError = process(response: saveResponse, data: saveData) {
                throw saveNewTokenRequestError
            }
            self.secureStorage.save(key: StorageKey.refreshToken, value: authenticationToken.refreshToken)
            self.secureStorage.save(key: StorageKey.tokenValidated, value: true)
            return authenticationToken.token
        }
        
        func clearDataAndLogOut() {
            self.secureStorage.remove(key: StorageKey.token)
            self.secureStorage.remove(key: StorageKey.refreshToken)
            self.secureStorage.remove(key: StorageKey.username)
            self.secureStorage.remove(key: StorageKey.tokenValidated)
            delegate?.userNotLoggedIn()
        }
        
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let getNewTokenURL = URL(string: "http://\(hostname)/jwt_life_cycle_maintainer_get_new_token"),
            let saveNewTokenURL = URL(string: "http://\(hostname)/jwt_life_cycle_maintainer_save_new_token")
        else {
            throw AppError.custom(message: "TODO") //TODO:
        }
        
        if storedTokenValidated == false {
            token = try await attemptTokenRefresh(newTokenURL: getNewTokenURL, saveTokenURL: saveNewTokenURL)
        }
        let mutableURLRequest = MutableURLRequest(url: urlString)
        mutableURLRequest.httpMethod = urlMethod
        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        mutableURLRequest.httpBody = request.httpBody
        
        let (data, response) = try await URLSession.shared.data(for: mutableURLRequest as URLRequest)
        guard var appError = process(response: response, data: data) else {
            return data
        }
        switch appError {
        case .sessionExpired:
            self.secureStorage.save(key: StorageKey.tokenValidated, value: false)
            do {
                token = try await attemptTokenRefresh(newTokenURL: getNewTokenURL, saveTokenURL: saveNewTokenURL)
                mutableURLRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: mutableURLRequest as URLRequest)
                if let error = process(response: response, data: data) {
                    throw error
                }
                return data
            } catch let error as AppError {
                appError = error
                switch appError{
                case .sessionInvalid:
                    clearDataAndLogOut()
                default:
                    throw error
                }
            } catch let error {
                throw error
            }
        case .sessionInvalid:
            clearDataAndLogOut()
        default:
            throw appError
        }
        
        throw appError
    }
    
    func process(error: Error) -> AppError {
        if let error = error as? NSError {
            switch error.code {
            case -1004:
                return .hostNotAvailable
            default:
                return .custom(message: "TODO")
            }
        }
        return .custom(message: "TODO")
    }
    
    func createURLRequest(baseURL: String, object: Codable) -> URL? {
        let jsonEncoder = JSONEncoder()
        var urlComponents = URLComponents(string: baseURL)
        do {
            let encodedData = try jsonEncoder.encode(object)
            guard let jsonObject = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any] else {
                return nil
            }
            var queryItems: [URLQueryItem] = []
            for (key, value) in jsonObject {
                if let stringValue = value as? String {
                    queryItems.append(URLQueryItem(name: key, value: stringValue))
                } else if let numberValue = value as? NSNumber {
                    queryItems.append(URLQueryItem(name: key, value: numberValue.stringValue))
                } else if let boolValue = value as? Bool {
                    queryItems.append(URLQueryItem(name: key, value: boolValue ? "true": "false"))
                }
            }
            urlComponents?.queryItems = queryItems
            return urlComponents?.url
        } catch {
            return nil
        }
    }
    
    func processDataForAuthenticationToken(data: Data) -> AuthenticationToken? {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if let responseDict = json?["response"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                return try JSONDecoder().decode(AuthenticationToken.self, from: jsonData)
            }
        } catch {
            
        }
        return nil
    }
    
    func fetchToken(hostname: String, username: String, password: String) async -> Result<AuthenticationToken, AppError> {
        guard let url = URL(string: "http://\(hostname)/login") else {
            return .failure(.custom(message: "TODO"))
        }
        let body = LoginCredentials(username: username, password: password)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var appError: AppError = AppError.custom(message: "Unable to handle response")
        do {
            request.httpBody = try? JSONEncoder().encode(body)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            if let appError = process(response: response, data: data) {
                throw appError
            }
            if let authenticationToken = processDataForAuthenticationToken(data: data) {
                return .success(authenticationToken)
            }
        }
        catch let error as AppError {
            appError = error
        }
        catch {
            appError = AppError.custom(message: "Unhandled response")
        }
        return .failure(appError)
    }
    
    func updateSectionEntry(listSectionWithEntry: ListSectionWithEntry) async -> Result<ListSectionWithEntry,ItemListError> {
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String
        else {
            return .failure(.todo)
        }
        let updateItem = UpdateItem(
            listID: listSectionWithEntry.listID,
            listName: listSectionWithEntry.listName,
            entryID: listSectionWithEntry.entryID,
            entryName: listSectionWithEntry.entryName,
            entryIsCheckMarked: listSectionWithEntry.entryIsCheckMarked
        )
        guard
            let token = self.secureStorage.retrieve(key: .token) as? String,
            let url = createURLRequest(baseURL: "http://\(hostname)/update_list_entry_values", object: updateItem)
        else {
            return .failure(.todo)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 5
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(updateItem)
            let data = try await executeNetworkCall(for: urlRequest)
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if let responseDict = json?["response"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                let listSectionWithEntry = try JSONDecoder().decode(ListSectionWithEntry.self, from: jsonData)
                return .success(listSectionWithEntry)
            }
        } catch let error {
            print("Failure \(error)")// TODO: Return error
        }
        return .failure(.todo)
    }

    // Function which sends to the backend the ability to create a new list
    func createNewList(listName: String) async -> Error? {
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let url = URL(string: "http://\(hostname)/create_new_list")
        else {
            return GenericError.everything //TODO:
        }
        guard let token = self.secureStorage.retrieve(key: .token) as? String else {
            return GenericError.everything
        }
        let createList = CreateList(
            listName: listName
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            request.httpBody = try JSONEncoder().encode(createList)
            let data = try await executeNetworkCall(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if json?["response"] as? [String: Any] != nil {
                return nil
            }
        } catch {
            print("Failure")// TODO: Return error
        }
        return GenericError.everything
    }
    
    // This function is both to add an item or update item. The presence of sectionID is to update item
    func addToList(sectionID: UInt?, listName: String, entryName: String) async -> Result<ListSectionWithEntry,Error> {
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let url = URL(string: "http://\(hostname)/add_new_item_to_list")
        else {
            return .failure(GenericError.everything) //TODO:
        }
        guard let token = self.secureStorage.retrieve(key: .token) as? String else {
            return .failure(GenericError.everything)
        }
        let addItem = AddItem(
            id: sectionID,
            listName: listName,
            entryName: entryName
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            request.httpBody = try JSONEncoder().encode(addItem)
            let data = try await executeNetworkCall(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if let responseDict = json?["response"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                let listSectionWithEntry = try JSONDecoder().decode(ListSectionWithEntry.self, from: jsonData)
                return .success(listSectionWithEntry)
            }
            return .failure(GenericError.everything)
        } catch {
            print("Failure")// TODO: Return error
            return .failure(error)
        }
    }
    
    func searchBackend(for text: String, listName: String) async -> [ListSectionWithEntry] {
        let searchRequest = SearchRequest(
            searchRequest: text,
            listName: listName
        )
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let url = createURLRequest(baseURL: "http://\(hostname)/find_items_for_user", object: searchRequest)
        else {
            return [] //TODO:
        }
        guard let token = self.secureStorage.retrieve(key: .token) as? String else {
            return [] // TODO:
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let data = try await executeNetworkCall(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if let responseDict = json?["response"] as? [Any] {
                
                let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                let listArray = try JSONDecoder().decode([ListSectionWithEntry].self, from: jsonData)
                return listArray
            }
        } catch let error {
            print(">> \(error)")
            print("")
        }
        return [] // TODO:
    }
    
    func removeListName(listName: String) async -> Result<[ResponseListNamesWithIDs],ItemListError> {
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let url = URL(string: "http://\(hostname)/return_remaining_lists_after_removal_of_list_name")
        else {
            return .failure(.todo)
        }
        guard let token = self.secureStorage.retrieve(key: .token) as? String else {
            return .failure(.todo)
        }
        let removeListName = RemoveListName(listName: listName)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(removeListName)
        request.timeoutInterval = 10
        
        do {
            let data = try await executeNetworkCall(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if let responseDictionary = json?["response"] as? [[String: String]] {
                let jsonData = try JSONSerialization.data(withJSONObject: responseDictionary, options: [])
                let listNamesWithIDs = try JSONDecoder().decode([ResponseListNamesWithIDs].self, from: jsonData)
                return .success(listNamesWithIDs)
            }
        } catch let error {
            print(">> \(error)")
            print("")
        }
        return .failure(.todo)
    }

    /**
    Function which returns all listNames based off of the token. This returns the list names for the user which are stored on the backend.
    - Throws: 
        * if URL is not valid
        * if data is not valid
    - Returns: [String]
    */
    func fetchListNamesWithIDs() async -> Result<[ResponseListNamesWithIDs],AppError> {
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let url = URL(string: "http://\(hostname)/retrieve_list_names")
        else {
            return .failure(.custom(message: "TODO"))
        }
        guard let token = self.secureStorage.retrieve(key: .token) as? String else {
            return .failure(.custom(message: "TODO"))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let data = try await executeNetworkCall(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            guard let response = json?["response"] as? [String: Any] else {
                return .failure(.custom(message: "TODO"))
            }
            
            if let responseDictionary = response["list_names"] as? [[String: String]] {
                let jsonData = try JSONSerialization.data(withJSONObject: responseDictionary, options: [])
                let listNamesWithIDs = try JSONDecoder().decode([ResponseListNamesWithIDs].self, from: jsonData)
                return .success(listNamesWithIDs)
            }
        }catch let appError as AppError {
            return .failure(appError)
        }
        catch let error {
            return .failure(process(error: error))
        }
        return .failure(.custom(message: "TODO"))
    }
    
    func fetchList(for listName: String, directionToReadList: DirectionToReadList) async -> Result<[ListSectionWithEntry], AppError> {
//        if case .old(_) = directionToReadList {
//            if BackendAPI.isLoadingingOlderData {
//                return .failure(.todo)
//            }
//            BackendAPI.isLoadingingOlderData = true
//        }
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String
        else {
            return .failure(.custom(message: "TODO"))
        }
        let viewList = ViewList(listName: listName, directionToReadList: DirectionToReadList.initial)
        guard
            let token = self.secureStorage.retrieve(key: .token) as? String,
            let url = createURLRequest(baseURL: "http://\(hostname)/retrieve_list", object: viewList)
        else {
            return .failure(.custom(message: "TODO"))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let data = try await executeNetworkCall(for: request)
//            if case .old(_) = directionToReadList {
//                BackendAPI.isLoadingingOlderData = false
//            }
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if let responseDict = json?["response"] as? [Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                let listSections = try JSONDecoder().decode([ListSectionWithEntry].self, from: jsonData)
                return .success(listSections)
            }
        } catch let error {
            print(">> \(error)")
            print("")
        }
        return .failure(.custom(message: "TODO"))
    }
    
    func deleteFromList(entry: ListEntry) async -> Error? {
        let deleteEntry = DeleteEntry(
            entryID: entry.entryID
        )
        guard
            let hostname = self.secureStorage.retrieve(key: .endpoint) as? String,
            let url = createURLRequest(baseURL: "http://\(hostname)/delete_entry", object: deleteEntry)
        else {
            return nil //TODO:
        }
        guard let token = self.secureStorage.retrieve(key: .token) as? String else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5
        
        do {
//            request.httpBody = try JSONEncoder().encode(deleteEntry)
            let data = try await executeNetworkCall(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any]
            if json?["response"] as? [String: Any] != nil {
                return nil
            }
        } catch {
            print("Failure")// TODO: Return error
        }
        return GenericError.everything // TODO: Error
    }
}
