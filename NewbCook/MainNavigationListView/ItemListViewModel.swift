//
//  MainScreenModel.swift
//  LocalNotes
//
//  Created by krow on 08-03-23.
//

import Foundation
import SwiftUI
import Combine

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

enum ItemListViewModelStatus {
    case loadingList
    case listeningToBackend
    case listeningToBackendButNoListExists
    case failure(AppError)
}

struct ResponseListNamesWithIDs: Codable {
    let listID: String
    let listName: String
    private enum CodingKeys: String, CodingKey {
        case listID = "list_id"
        case listName = "list_name"
    }
}

public struct AuthenticationToken: Codable {
    let token: String
    let refreshToken: String
    
    private enum CodingKeys: String, CodingKey {
        case token
        case refreshToken = "refresh_token"
    }
}

/**
A class that will keep track of the sections which will be separated by what is received from the backend, what is completed, and the special sections.
*/
class SectionManager: ObservableObject {
    var listName: String = "Loading..."
    var completedSection: [ListSectionWithEntry] = []
    var uncompletedSection: [ListSectionWithEntry] = []

    var searchSection: [ListSectionWithEntry] = []
    var specialBottomSection: ListSection?
    
    init() {}
    
    func insertIntoCompletedSection(_ entry: [ListSectionWithEntry]) {
        completedSection = entry + completedSection
    }
    
    func insertIntoCompletedSection(_ entry: ListSectionWithEntry) {
        completedSection.insert(entry, at: 0)
    }

    func removeFromCompletedSection(_ entry: ListSectionWithEntry) {
        var indexSection = 0
        var didFindEntry = false
        while indexSection < completedSection.count {
            if completedSection[indexSection].entryID == entry.entryID {
                didFindEntry = true
                break
            }
            indexSection += 1
        }
        if didFindEntry {
            completedSection.remove(at: indexSection)
        }
    }
    
    func replaceBottomSection(entry: ListSection) {
        specialBottomSection = entry
    }
    
    func switchToNewList(listName: String) {
        self.listName = listName
        uncompletedSection = []
        completedSection = []
        specialBottomSection = nil
    }
    
    func getSearchResultSections(found sections: [ListSectionWithEntry], activeListName: String, searchText: String) -> [ListSection] {
        // In case clearing search result it is necessary set searchSections to []
        self.searchSection = sections
        guard let firstSection = sections.first else {
            return []
        }
        var returnListSection: [ListSection] = []
        var entries: [ListEntry] = []
        for section in sections {
            let newEntry = ListEntry(entryID: section.entryID, entryIsCheckMarked: section.entryIsCheckMarked, entryName: section.entryName)
            entries.append(newEntry)
        }
        
        let addToActiveListSection = ListSection(
            specialSection: .itemsFound,
            listID: firstSection.listID,
            listName: activeListName,
            sectionID: firstSection.sectionID,
            sectionName: "Items Found",
            sectionEntries: entries
        )
        returnListSection.append(addToActiveListSection)
        return returnListSection
    }
    
    func addEntries(_ entries: [ListSectionWithEntry]) {
        entries.forEach { entry in
            if entry.sectionType == SectionType.completed {
                self.completedSection.insert(entry, at: 0)
            } else if entry.sectionType == SectionType.uncompleted {
                self.uncompletedSection.insert(entry, at: 0)
            }
        }
    }
    
    func removeEntry(_ entry: ListSectionWithEntry) {
        var index = 0
        if entry.entryIsCheckMarked {
            while index < self.completedSection.count {
                if self.completedSection[index].entryID == entry.entryID {
                    self.completedSection.remove(at: index)
                    break
                }
                index += 1
            }
        } else {
            while index < self.uncompletedSection.count {
                if self.uncompletedSection[index].entryID == entry.entryID {
                    self.uncompletedSection.remove(at: index)
                    break
                }
                index += 1
            }
        }
    }
    
    // Update not only the entries for a list, but assumes all entries are under the same list name, hence listName is updated
    // If an entry cannot be found, then add it to the appropraite SectionType (completed, uncompleted)
    func updateEntries(_ entries: [ListSectionWithEntry]) {
        guard let firstSection = entries.first else {
            return
        }
        self.listName = firstSection.listName
        entries.forEach { entry in
            var didUpdateEntry = false
            if let index = completedSection.firstIndex(where: { entryFound in
                entryFound.entryID == entry.entryID
            }) {
                completedSection[index].entryName = entry.entryName
                if entry.entryIsCheckMarked == false {
                    completedSection.remove(at: index)
                    uncompletedSection.insert(entry, at: 0)
                }
                didUpdateEntry = true
            }
            else if let index = uncompletedSection.firstIndex(where: { entryFound in
                entryFound.entryID == entry.entryID
            }) {
                uncompletedSection[index].entryName = entry.entryName
                if entry.entryIsCheckMarked {
                    uncompletedSection.remove(at: index)
                    completedSection.insert(entry, at: 0)
                }
                didUpdateEntry = true
            }
            if didUpdateEntry == false {
                if entry.entryIsCheckMarked {
                    completedSection.insert(entry, at: 0)
                } else {
                    uncompletedSection.insert(entry, at: 0)
                }
            }
            if let index = searchSection.firstIndex(where: { entryFound in
                entryFound.entryID == entry.entryID
            }) {
                searchSection[index].entryIsCheckMarked = entry.entryIsCheckMarked
            }
        }
    }
    
    func updateSearchReult(for entry: ListSectionWithEntry) {
        var index = 0
        while index < searchSection.count {
            if (entry.entryID == searchSection[index].entryID) {
                searchSection[index].entryIsCheckMarked = entry.entryIsCheckMarked
                break
            }
            index += 1
        }
    }
    
    func getSectionsFormattedForSearch() -> [ListSection] {
        guard let firstSearchSection = searchSection.first else {
            return []
        }
        var listSection = ListSection(
            specialSection: .itemsFound,
            listID: firstSearchSection.listID,
            listName: listName,
            sectionID: firstSearchSection.sectionID,
            sectionName: "",
            sectionEntries: []
        )
        searchSection.forEach { listSectionWithEntry in
            let entry = ListEntry(
                entryID: listSectionWithEntry.entryID,
                entryIsCheckMarked: listSectionWithEntry.entryIsCheckMarked,
                entryName: listSectionWithEntry.entryName
            )
            listSection.sectionEntries.append(entry)
        }
        return [listSection]
    }
    
    func getAllSections() -> [ListSection] {
        var returnSections: [ListSection] = []

        if let firstUncompletedSection = self.uncompletedSection.first {
            var entries: [ListEntry] = []
            for section in uncompletedSection {
                let entry = ListEntry(entryID: section.entryID, entryIsCheckMarked: section.entryIsCheckMarked, entryName: section.entryName)
                entries.append(entry)
            }
            let completedSection = ListSection(
                specialSection: .uncompleted,
                listID: firstUncompletedSection.listID,
                listName: listName,
                sectionID: firstUncompletedSection.sectionID,
                sectionName: "Other",
                sectionEntries: entries)
            returnSections.append(completedSection)
        }
        
        if let firstCompletedSection = self.completedSection.first {
            var entries: [ListEntry] = []
            for section in completedSection {
                let entry = ListEntry(entryID: section.entryID, entryIsCheckMarked: section.entryIsCheckMarked, entryName: section.entryName)
                entries.append(entry)
            }
            
            let completedSection = ListSection(
                specialSection: .completed,
                listID: firstCompletedSection.listID,
                listName: listName,
                sectionID: firstCompletedSection.sectionID,
                sectionName: "Completed",
                sectionEntries: entries)
            returnSections.append(completedSection)
        }
        if let specialBottomSection = self.specialBottomSection {
            returnSections += [specialBottomSection]
        }
        return returnSections
    }
}

@MainActor
class ItemListViewModel: ObservableObject {
    @Published var itemViewModelStatus: ItemListViewModelStatus = .loadingList
    @Published var isLoadingData: Bool = false
    
    @Published var listNonSearchSections: [ListSection] = [] // All uncompleted sections and the completed section
    @Published var listSearchSections: [ListSection] = [] // All search result found for currently text to search for
    
    var listNamesWithIDs: [ResponseListNamesWithIDs] = []
    @Published var activeListName: String = ""
    
    let secureStorage: SecureStorage
    let sectionManager = SectionManager()
    var searchText: String = ""
    
    var passthrough = PassthroughSubject<ItemListViewModelStatus, AppError>()
    var cancellables: Set<AnyCancellable> = []
    
    static var loadingMoreToList = ListSection(specialSection: .loadingMoreToList, listID: 0, listName: "", sectionID: 5, sectionName: "LoadingMoreToList", sectionEntries: [])
    static var listEnd = ListSection(specialSection: .listEnd, listID: 0, listName: "", sectionID: 0, sectionName: "NeedToLoadMore", sectionEntries: [])
    
    public var isCheckingDatabase: Bool {
        if self.retrieveTokenFromStorage() == nil {
            return true
        }
        return false
    }
    var loadingViewFirstTime = false
    let backendAPI: BackendAPI
    
    init(secureStorage: SecureStorage, backendAPI: BackendAPI = ConcreteBackendAPI()) {
        self.secureStorage = secureStorage
        self.backendAPI = backendAPI
        
        self.passthrough.sink { appError in
            print(appError)
        } receiveValue: { [weak self] status in
            self?.itemViewModelStatus = status
        }
        .store(in: &cancellables)
    }
    
    func connectWithBackend(using listName: String? = nil) {
        passthrough.send(.loadingList)
        
        func fetchListSections(listName: String) async {
            let result = await updateListSections(listName: listName)
            switch result {
            case .success(_):
                passthrough.send(.listeningToBackend)
            case .failure(let error):
                passthrough.send(.failure(error))
            }
        }
        Task {
            if let listName = listName {
                await fetchListSections(listName: listName)
            }
            else {
                let result = await self.pullInitialList()
                switch result {
                case .success(let listName):
                    if let listName = listName {
                        activeListName = listName
                        await fetchListSections(listName: listName)
                    } else {
                        passthrough.send(.listeningToBackendButNoListExists)
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    func searchForItem(name searchText: String) async {
        self.searchText = searchText
        if searchText.count == 0 {
            self.listSearchSections = sectionManager.getSearchResultSections(found: [], activeListName: activeListName, searchText: searchText)
            return
        }
        let searchRequest = ConcreteTransmitSearchRequest(
            searchRequest: searchText,
            listName: activeListName
        )
        let result: Result<[ListSectionWithEntry], AppError> = await self.backendAPI.execute(item: searchRequest)
        switch result {
        case .success(let sections):
            self.listSearchSections = sectionManager.getSearchResultSections(found: sections, activeListName: activeListName, searchText: searchText)
        case .failure(let error):
            print("TODO: \(error)")
        }
    }
    
    func switchList(using listName: String) async -> AppError? {
        let fetchList = ConcreteTransmitFetchList(listName: listName)
        let result: Result<[ListSectionWithEntry], AppError> = await self.backendAPI.execute(item: fetchList)
        switch result {
        case .success(let sectionsWithEntry):
            self.updateListToUse(sectionsWithEntry: sectionsWithEntry, listName: listName)
            return nil
        case .failure(let error):
            self.passthrough.send(.failure(error))
            return error
        }
    }
    
    func refreshList(using listName: String) async {
        let fetchList = ConcreteTransmitFetchList(listName: listName)
        let result: Result<[ListSectionWithEntry], AppError> = await self.backendAPI.execute(item: fetchList)
        switch result {
        case .success(let sectionsWithEntry):
            self.updateListToUse(sectionsWithEntry: sectionsWithEntry, listName: listName)
        case .failure(let error):
            print("TODO: \(error)")
        }
    }
    
    func deleteListName(listName: String) async -> Result<[ResponseListNamesWithIDs], AppError> {
        let deleteList = ConcreteTransmitDeleteList(listName: listName)
        let result: Result<[ResponseListNamesWithIDs], AppError> = await backendAPI.execute(item: deleteList)
        switch result {
        case .success(_):
            let availableLists = await pullAvailableLists()
            if listName == activeListName {
                switch availableLists {
                case .success(let listIDs):
                    if let first = listIDs.first {
                        await switchList(using: first.listName)
                    }
                case .failure(let error) :
                    print("TODO: \(error)")
                }
                self.updateListToUse(sectionsWithEntry: [], listName: nil)
            }
            return availableLists
        case .failure(_):
            // TODO: record metric
            self.updateListToUse(sectionsWithEntry: [], listName: "Select List")
        }
        return .failure(.custom(message: "TODO"))
    }
}

extension ItemListViewModel {

    /**
    Pulls the available lists from the backend which are registered to the token provided.
    - Returns: A Result object that contains either a list of list names or an ItemListError.
    */
    func pullAvailableLists() async -> Result<[ResponseListNamesWithIDs], AppError> {
        let result: Result<[ResponseListNamesWithIDs], AppError> = await self.backendAPI.execute(item: ConcreteTransmitFetchListsWithIDs())
        switch result {
        case .success(let listNamesWithIDs):
            self.listNamesWithIDs = listNamesWithIDs
            return .success(listNamesWithIDs)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /**
        This function will pull the initial list from the backend.
        - Parameter listName: The name of the list to pull from the backend.
        - Returns: A Result object that contains either a list of ListSections or an ItemListError.
    */
    func pullInitialList() async -> Result<String?, AppError> {
        let result = await pullAvailableLists()
        switch result {
        case .success(let listNamesWithIDs):
            if let listNameWithID = listNamesWithIDs.first {
                let startTime = Date()
                let fetchList = ConcreteTransmitFetchList(listName: listNameWithID.listName)
                let result: Result<[ListSectionWithEntry], AppError> = await self.backendAPI.execute(item: fetchList)
                let endTime = Date()
                let timeDifference = endTime.timeIntervalSince(startTime)
                print(timeDifference)
                if timeDifference < 1 {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 - Int(timeDifference * 1_000_000_000)))
                    } catch {
                        // Skip throw and just refresh if possible
                    }
                }
                switch result {
                case .success(let sectionWithEntry):
                    self.sectionManager.switchToNewList(listName: listNameWithID.listName)
                    self.sectionManager.addEntries(sectionWithEntry)
                    self.sectionManager.replaceBottomSection(entry: ItemListViewModel.listEnd)
                    self.listNonSearchSections = sectionManager.getAllSections()
                    self.activeListName = listNameWithID.listName
                    return .success(listNameWithID.listName)
                case .failure(let error):
                    return .failure(.custom(message: "TODO: \(error)"))
                }
            } else {
                // TODO if there i no list then allow user to create a list
                return .success(nil)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    private func updateListToUse(sectionsWithEntry: [ListSectionWithEntry], listName: String?) {
        if let listName = listName {
            self.sectionManager.switchToNewList(listName: listName)
            self.sectionManager.updateEntries(sectionsWithEntry)
            self.sectionManager.replaceBottomSection(entry: ItemListViewModel.listEnd)
            
            self.listNonSearchSections = sectionManager.getAllSections()
            self.activeListName = listName
            passthrough.send(.listeningToBackend)
        } else {
            self.activeListName = ""
            passthrough.send(.listeningToBackendButNoListExists)
        }
    }
    
    func updateListSections(listName: String) async -> Result<[ListSectionWithEntry], AppError> {
        if isLoadingData {
            return .success([])
        }
        isLoadingData = true
        let fetchList = ConcreteTransmitFetchList(listName: listName)
        let result: Result<[ListSectionWithEntry], AppError> = await self.backendAPI.execute(item: fetchList)
        isLoadingData = false
        switch result {
        case .success(let sectionsWithEntry):
            self.sectionManager.updateEntries(sectionsWithEntry)
            return .success(sectionsWithEntry)
            // TODO: Pagination
        case .failure(let error):
            return .failure(error)
        }
    }
    
    private func deleteSectionItemArray(for sections: inout [ListSection], entryID: UInt) {
        var sectionIndex = 0
        var entryIndex = 0
        while sectionIndex < sections.count {
            var entries = sections[sectionIndex].sectionEntries
            entryIndex = 0
            while entryIndex < entries.count {
                if entries[entryIndex].entryID == entryID {
                    entries.remove(at: entryIndex)
                    sections[sectionIndex].sectionEntries = entries
                    break
                }
                entryIndex += 1
            }
            if entries.count == 0 {
                sections.remove(at: sectionIndex)
            }
            sectionIndex += 1
        }
    }
    
    func deleteSectionItem(entry entryToDelete: ListSection, index: Int, listID: UInt) async {
        let entry = entryToDelete.sectionEntries[index]
        let id = entryToDelete.sectionID
        let sectionName = entryToDelete.sectionName
        let entryName = entry.entryName
        let entryIsCheckMarked = entry.entryIsCheckMarked
        let sectionWithEntry = ListSectionWithEntry(
            listID: listID,
            listName: sectionName,
            sectionID: id,
            sectionName: sectionName,
            sectionType: .unspecified,
            entryID: entry.entryID,
            entryName: entryName,
            entryIsCheckMarked: entryIsCheckMarked
        )
        let deleteEntry = ConcreteTransmitDeleteItem(entryID: entry.entryID)
        let result: Result<[String: String], AppError> = await self.backendAPI.execute(item: deleteEntry)
        switch result {
        case .success(_):
            self.sectionManager.removeEntry(sectionWithEntry)
            self.listNonSearchSections = self.sectionManager.getAllSections()
        case .failure(let error):
            print("Error \(error)") // TODO: Save metrics
        }
    }
    
    func isAuthenticated() -> Bool {
        return self.retrieveTokenFromStorage() != nil
    }
    
    func retrieveTokenFromStorage() -> String? {
        return self.secureStorage.retrieve(key: .token) as? String
    }
    
    func updateEntry(sectionWithEntry: ListSectionWithEntry) async -> Error? {
        let transmitUpdateItem = ConcreteTransmitUpdateItem(
            listID: sectionWithEntry.listID,
            listName: sectionWithEntry.listName,
            entryID: sectionWithEntry.entryID,
            entryName: sectionWithEntry.entryName,
            entryIsCheckMarked: sectionWithEntry.entryIsCheckMarked
        )
        let result: Result<ListSectionWithEntry, AppError> = await self.backendAPI.execute(item: transmitUpdateItem)
        switch result {
        case .success(_):
            self.sectionManager.updateEntries([sectionWithEntry])
            self.listNonSearchSections = self.sectionManager.getAllSections()
            self.activeListName = self.sectionManager.listName
            if searchText.count > 0 {
                self.listSearchSections = sectionManager.getSectionsFormattedForSearch()
            }
        case .failure(_):
            print("TODO")
        }
        
        return nil
    }
    
    func createNewList(listName: String) async -> AppError? {
        let createNewList = ConcreteTransmitCreateNewList(listName: listName)
        let result: Result<ConcreteListParameters, AppError> = await backendAPI.execute(item: createNewList)
        switch result {
        case .success(_):
            updateListToUse(sectionsWithEntry: [], listName: listName)
        case .failure(let error):
            print("TODO: \(error)")
        }
        
        return nil
    }
    
    func addToList(itemName: String, listName: String? = nil) async -> Error? {
        let listName = listName != nil ? listName! : activeListName
        let transmitAddItemToList = ConcreteTransmitAddItemToList(id: nil, listName: listName, entryName: itemName)
        let result: Result<ListSectionWithEntry, AppError> = await backendAPI.execute(item: transmitAddItemToList)
        switch result {
        case .success(let new_entry):
            self.sectionManager.addEntries([new_entry])
            self.listNonSearchSections = sectionManager.getAllSections()
            return nil
        case .failure(let failure):
            print(failure)
            return failure
        }
    }
    
    private func addToSection(new sectionWithEntry: ListSectionWithEntry) {
        var sectionIndex = 0
        var sections: [ListSection] = self.listNonSearchSections
        
        while sectionIndex < sections.count {
            if sections[sectionIndex].sectionID == sectionWithEntry.sectionID {
                var entryIndex = 0
                var entries = sections[sectionIndex].sectionEntries
                while entryIndex < entries.count {
                    if (entries[entryIndex].entryID == 0) {
                        entries.remove(at: entryIndex)
                    }
                    entryIndex += 1
                }
                sections[sectionIndex].sectionEntries = entries
                let listEntry = ListEntry(
                    entryID: sectionWithEntry.entryID,
                    entryIsCheckMarked: sectionWithEntry.entryIsCheckMarked,
                    entryName: sectionWithEntry.entryName
                )
                sections[sectionIndex].sectionEntries.insert(listEntry, at: 0)
            }
            sectionIndex += 1
        }
        self.listNonSearchSections = sections
    }
}

extension ItemListViewModel {
    convenience init() {
        self.init(secureStorage: KeychainStorage.shared)
    }
}

//extension MainScreenViewModel {
//    init() {
//        let authentication = Authentication()
//        self.init(authentication: authentication)
//    }
//}
