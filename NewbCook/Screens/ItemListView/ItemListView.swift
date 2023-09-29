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
    
    @StateObject var viewModel: ItemListViewModel
    @State private var searchText: String = ""
    @State var popoverListNames = false
    @State var isSearching: Bool = false
    
    var body: some View {
        if popoverListNames {
            presentListNames()
        }
        else {
            presentAppropriateView()
        }
    }

    func presentListNames() -> some View {
        ProgressView()
        .popover(isPresented: $popoverListNames) {
            UserListNamesView(
                itemListViewModel: viewModel,
                popoverListNames: $popoverListNames
            )
        }
    }
    
    func presentAppropriateView() -> some View {
        Group {
            switch viewModel.itemViewModelStatus {
            case .loadingList:
                presentLoadingList()
            case .listeningToBackend:
                presentActiveList()
            case .listeningToBackendButNoListExists:
                presentNoListExistView()
            case .failure(let error):
                showErrorLoadingScreen(with: error)
            }
        }
    }
    
    func presentLoadingList() -> some View {
        VStack {
            Text("Connecting to server..")
                .task {
                    viewModel.connectWithBackend()
                }
            ProgressView()
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

    func presentNoListExistView() -> some View {
        VStack {
            Text("Create a new private list")
            showListButton()
        }
    }
    
    func showErrorLoadingScreen(with appError: AppError?) -> some View {
        VStack {
            Text("Error connecting to server")
            if let error = appError {
                Text("\(error.description)")
            }
            Button {
                loadingData = true
                Task {
                    let result = await viewModel.pullInitialList()
                    switch result {
                    case .success(_):
                        loadingData = false
                    case .failure(let error):
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
    
    func presentActiveList() -> some View {
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
                    .navigationTitle(viewModel.activeListName)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            showListButton()
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .listStyle(InsetGroupedListStyle())
                } else {
                    let sections = isSearching ? viewModel.listSearchSections : viewModel.listNonSearchSections
                    List(sections) { section in
                        if (showLoadingMoreSection(section: section)) {
                            Section("Loading More...") {
                                ProgressView()
                            }
                            .onAppear {
                                Task {
                                    let _ = await viewModel.updateListSections(listName: viewModel.activeListName)
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
                    .navigationTitle(viewModel.activeListName)
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
            await viewModel.refreshList(using: viewModel.activeListName)
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
    }
    
    func loopThroughSectionEntries(section: ListSection) -> some View {
        ForEach(section.sectionEntries) { entry in
            let sectionWithEntry = ListSectionWithEntry(
                listID: section.listID, // TODO:
                listName: viewModel.activeListName,
                sectionID: section.sectionID,
                sectionName: section.sectionName,
                sectionType: .unspecified, // TODO:
                entryID: entry.entryID,
                entryName: entry.entryName,
                entryIsCheckMarked: entry.entryIsCheckMarked
            )
            NavigationLink {
                AddModifySectionEntryView(
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
            viewModel: ItemListViewModel()
        )
    }
}
