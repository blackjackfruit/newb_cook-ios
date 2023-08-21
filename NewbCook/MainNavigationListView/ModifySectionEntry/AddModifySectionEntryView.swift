//
//  AddItem.swift
//  LocalNotes
//
//  Created by krow on 16-03-23.
//

import SwiftUI

enum SearchSectionEntryOptions {
    case section
    case entry
}

struct AddModifySectionEntryView: View {
    var listSectionWithEntry: ListSectionWithEntry
    
    @State var isAttemptingToSaveEntry = false
    @State var updatedListName: String = ""
    @State var entryName: String = ""
    @State var searchString: String = ""
    @State var foundSections: [String] = []
    @State var foundEntries: [String: String] = [:]
    @State var readyToShowResults = false
    
    @FocusState var entryTextFieldFocused: Bool
    
    var itemListViewModel: ItemListViewModel
    
    init(
        listSectionWithEntry: ListSectionWithEntry,
        itemListViewModel: ItemListViewModel
    ) {
        self.listSectionWithEntry = listSectionWithEntry
        self.itemListViewModel = itemListViewModel
        
        self._updatedListName = State(wrappedValue: listSectionWithEntry.listName)
        self._entryName = State(wrappedValue: listSectionWithEntry.entryName)
    }
    
    var saveButtonBackgroundColor: Color {
        textFieldsProperlyModified ? Color.blue: Color.gray
    }
    
    var body: some View {
        VStack(spacing: 0.0) {
            List {
                Section("List Name") {
                    TextField("List Name", text: $updatedListName)
                }
                Section("Item Name") {
                    TextField("Item Name", text: $entryName)
                }
                
                if (readyToShowResults) {
                    Section("Searching Previous Items") {
                        ForEach(0..<10, id: \.self) { item in
                            HStack {
                                Text("Group")
                                Text("TTT")
                            }
                        }
                    }
                } else if (itemListViewModel.isLoadingData) {
                    Section("Matching Items") {   
                        ProgressView()
                    }
                }
            }
            
            Button(action: {
                triggerSaveButton()
            }, label: {
                if isAttemptingToSaveEntry {
                    ProgressView()
                        .foregroundColor(Color.white)
                        .frame(height:50)
                        .frame(maxWidth: .infinity)
                        .background(saveButtonBackgroundColor)
                } else {
                    Text("Save")
                        .foregroundColor(Color.white)
                        .frame(height:50)
                        .frame(maxWidth: .infinity)
                        .background(saveButtonBackgroundColor)
                }
            })
            .cornerRadius(10.0)
            .padding(1.0)
            .disabled(!textFieldsProperlyModified)
        }
    }
    
    func triggerSaveButton() {
        isAttemptingToSaveEntry = true
        Task {
            let updatedSectionWithEntry = ListSectionWithEntry(
                listID: listSectionWithEntry.listID,
                listName: updatedListName,
                sectionID: listSectionWithEntry.sectionID,
                sectionName: listSectionWithEntry.sectionName,
                sectionType: listSectionWithEntry.sectionType,
                entryID: listSectionWithEntry.entryID,
                entryName: entryName,
                entryIsCheckMarked: listSectionWithEntry.entryIsCheckMarked
            )
            let error = await itemListViewModel.updateEntry(
                sectionWithEntry: updatedSectionWithEntry
            )
            self.isAttemptingToSaveEntry = false
            if let error = error {
                // Log metric
                print(error) // TODO: record metric
                return
            }
        }
    }
    
    var textFieldsProperlyModified: Bool {
        if
            self.updatedListName == self.listSectionWithEntry.listName &&
            self.entryName == self.listSectionWithEntry.entryName {
            return false
        }
        else if
            self.updatedListName.count > 0 &&
            self.entryName.count > 0 &&
            self.isAttemptingToSaveEntry == false
        {
            return true
        }
        return false
    }
}

//struct AddItem_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            AddModifySectionEntryView(
//                activeListName: .constant("BOo"),
//                sectionWithEntry:
//                    ListSectionWithEntry(
//                        listID: 0,
//                        listName: "list name",
//                        sectionID: 11,
//                        sectionName: "",
//                        sectionType: .unspecified,
//                        entryID: 111,
//                        entryName: "entry name",
//                        entryIsCheckMarked: true
//                    ),
//                itemListViewModel: ItemListViewModel()
//            )
//        }
//        .navigationTitle("Title")
//    }
//}
