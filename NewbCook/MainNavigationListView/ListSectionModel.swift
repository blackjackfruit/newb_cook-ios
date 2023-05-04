//
//  MainScreenModel.swift
//  LocalNotes
//
//  Created by krow on 08-03-23.
//

import Foundation

enum SectionType: String, Codable {
    case loadingMoreToList
    case itemsFound
    case uncompleted
    case completed
    case listEnd
    case unspecified
    
    private enum CodingKeys: String, CodingKey {
        case loadingMoreToList = "loading_more_to_list"
        case itemsFound = "items_found"
        case uncompleted = "uncompleted"
        case completed = "completed"
        case listEnd = "list_end"
        case unspecified = "unspecified"
    }
}

enum DirectionToReadList: String, Codable {
    case initial
}

struct DeleteEntry: Codable {
    var entryID: UInt
    
    private enum CodingKeys: String, CodingKey {
        case entryID = "entry_id"
    }
}

struct ListEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var entryID: UInt
    var entryIsCheckMarked: Bool
    var entryName: String
    enum CodingKeys: String, CodingKey {
        case entryID = "entry_id"
        case entryIsCheckMarked = "entry_is_check_marked"
        case entryName = "entry_name"
    }
}

struct ListSection: Codable, Identifiable {
    var id = UUID()
    var specialSection: SectionType
    var listID: UInt
    var listName: String
    var sectionID: UInt
    var sectionName: String
    var sectionEntries: [ListEntry]
    enum CodingKeys: String, CodingKey {
        case specialSection = "special_section"
        case listID = "list_id"
        case listName = "list_name"
        case sectionID = "section_id"
        case sectionName = "section_name"
        case sectionEntries = "section_entries"
    }
}

struct ListSectionWithEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var listID: UInt
    var listName: String
    var sectionID: UInt
    var sectionName: String
    var sectionType: SectionType
    var entryID: UInt
    var entryName: String
    var entryIsCheckMarked: Bool
    
    enum CodingKeys: String, CodingKey {
        case listID = "list_id"
        case listName = "list_name"
        case sectionID = "section_id"
        case sectionName = "section_name"
        case sectionType = "section_type"
        case entryID = "entry_id"
        case entryName = "entry_name"
        case entryIsCheckMarked = "entry_is_check_marked"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
