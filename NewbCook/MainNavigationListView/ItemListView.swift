//
//  ItemListView.swift
//  LocalNotes
//
//  Created by krow on 15-03-23.
//

import Foundation
import SwiftUI

class Model: ObservableObject {
    @Published var pushed = false
}

let loadingLists = "Loading Lists..."

enum FocusField {
    case createNewItem
}

struct ItemListView: View {
    @State var loadingData = true
    @State var appError: AppError?
    
    @Binding var isNotAuthenticated: Bool
    @State var showingAddItemView = false
    @StateObject var viewModel: ItemListViewModel
    @State private var searchText: String = ""
    @State var popoverListNames = false
    @State var activeListName: String = ""
    @State var noListAvailable = false
    @State var isSearching: Bool = false
    @State var listName: String = ""
    
    var body: some View {
        if popoverListNames {
            showingListNames()
        }
        else if noListAvailable && activeListName.count == 0 {
            noListAvailableView()
        }
        else if activeListName != listName {
            ProgressView().task {
                listName = activeListName
            }
            .hidden()
        }
        else if loadingData {
            showLoadingScreen()
        }
        else if appError != nil {
            showErrorLoadingScreen()
        }
        else {
            NavigationView {
                VStack {
                    SearchedView(
                        isSearching: $isSearching,
                        searchText: $searchText,
                        itemListViewModel: viewModel
                    )
                    if isSearching && searchText.count == 0 {
                        List {
                            
                        }
                        .navigationTitle(listName)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                showListButton()
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .listStyle(InsetGroupedListStyle())
                    } else if let listName = activeListName {
                        let sections = isSearching ? viewModel.listSearchSections : viewModel.listNonSearchSections
                        List(sections) { section in
                            if (showLoadingMoreSection(section: section)) {
                                Section("Loading More...") {
                                    ProgressView()
                                }
                                .onAppear {
                                    Task {
//                                        let directionToReadFrom = DirectionToReadList.old(fromSection: section.sectionID)
                                        let _ = await viewModel.updateListSections(listName: listName, directionToReadList: DirectionToReadList.initial)
                                    }
                                }
                            }
                            else if (showNoMoreSections(section: section)) {
                                Section("No more items to load"){}
                            }
                            else {
                                Section(section.sectionName) {
                                    loopThroughSectionEntries(section: section)
                                }
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .listStyle(InsetGroupedListStyle())
                        .navigationTitle(listName)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    isSearching = false
                                    searchText = ""
                                    popoverListNames = true
                                } label: {
                                    Image(systemName: "list.bullet.circle")
                                }
                            }
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .onChange(of: searchText, perform: { newValue in
                Task {
                    await viewModel.searchForItem(name: newValue)
                }
            })
            .refreshable {
                let startTime = Date()
                await viewModel.refreshList(using: activeListName)
                let endTime = Date()
                let timeDifference = endTime.timeIntervalSince(startTime)
                print(timeDifference)
                if timeDifference < 2 {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 - Int(timeDifference * 1_000_000_000)))
                    } catch {
                        // Skip throw and just refresh if possible
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("Foreground entered")
            }
//            .onAppear {
//                print("first")
//                Task {
//                    let result = await viewModel.pullInitialList()
//                    switch result {
//                    case .success(let listName):
//                        activeListName = listName
//                    case .failure(let error):
//                        activeListName = "Error"
//                        loadingData = true
//                        print(error) // TODO: record metric
//                    }
//                }
//            }
        }
    }
    
    func showListButton() -> some View {
        Button {
            isSearching = false
            searchText = ""
            popoverListNames = true
        } label: {
            Image(systemName: "list.bullet.circle")
        }
    }
    
    func showingListNames() -> some View {
        ProgressView()
        .popover(isPresented: $popoverListNames) {
            UserListNamesView(
                itemListViewModel: viewModel,
                popoverListNames: $popoverListNames,
                activeListName: $activeListName
            )
        }
    }
    
    func noListAvailableView() -> some View {
        VStack {
            Text("Create a new private list")
            showListButton()
        }
    }
    
    func showErrorLoadingScreen() -> some View {
        VStack {
            Text("Error connecting to server")
            if let error = appError {
                Text("\(error.description)")
            }
            Button {
                loadingData = true
                appError = nil
                Task {
                    let result = await viewModel.pullInitialList()
                    switch result {
                    case .success(let listName):
                        activeListName = listName ?? ""
                        loadingData = false
                        appError = nil
                    case .failure(let error):
                        activeListName = "Error"
                        appError = error
                        print(error) // TODO: record metric
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise.icloud")
                .foregroundColor(Color.white)
                .padding(10)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
    }
    
    func showLoadingScreen() -> some View {
        VStack {
            Text("Connecting to server..")
            ProgressView()
            .task {
                let result = await viewModel.pullInitialList()
                switch result {
                case .success(let listName):
                    if let listName = listName {
                        activeListName = listName ?? ""
                        loadingData = false
                        appError = nil
                    } else {
                        noListAvailable = true
                    }
                case .failure(let error):
                    activeListName = "Error"
                    appError = error
                    loadingData = false
                    print(error) // TODO: record metric
                }
            }
        }
    }
    
    func loopThroughSectionEntries(section: ListSection) -> some View {
        ForEach(section.sectionEntries) { entry in
            let sectionWithEntry = ListSectionWithEntry(
                listID: section.listID, // TODO:
                listName: activeListName,
                sectionID: section.sectionID,
                sectionName: section.sectionName,
                sectionType: .unspecified, // TODO:
                entryID: entry.entryID,
                entryName: entry.entryName,
                entryIsCheckMarked: entry.entryIsCheckMarked
            )
            NavigationLink {
                AddModifySectionEntryView(
                                activeListName: $activeListName,
                                listSectionWithEntry: sectionWithEntry,
                                itemListViewModel: viewModel
                            )
                            .navigationTitle("Update")
            } label: {
                RowView(
                    sectionWithEntry: sectionWithEntry,
                    itemListViewModel: viewModel
                )
            }
        }
        .onDelete { indexSet in
            deleteEntry(from: section, indexSet: indexSet)
        }
    }
    
    func showLoadingMoreSection(section: ListSection) -> Bool {
        if section.sectionName == ItemListViewModel.loadingMoreToList.sectionName {
            return true
        }
        return false
    }
    
    func showNoMoreSections(section: ListSection) -> Bool {
        if (section.sectionName == ItemListViewModel.listEnd.sectionName) {
            return true
        }
        return false
    }
    
    func deleteEntry(from section: ListSection, indexSet: IndexSet) {
        guard let index = indexSet.first else {
            return
        }
        Task {
            await viewModel.deleteSectionItem(entry: section, index: index, listID: 0)
        }
    }
}

struct ItemListView_Previews: PreviewProvider {
    static var previews: some View {
        ItemListView(
            isNotAuthenticated: .constant(true),
            viewModel: ItemListViewModel()
        )
    }
}
