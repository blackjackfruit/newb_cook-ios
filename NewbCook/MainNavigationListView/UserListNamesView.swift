//
//  OptionalListView.swift
//  LocalNotes
//
//  Created by krow on 24-03-23.
//

import SwiftUI

struct UserListNamesView: View {
    
    let itemListViewModel: ItemListViewModel
    @Binding var popoverListNames: Bool
    @Binding var activeListName: String
    @State var listNames: [String] = []
    @State var isLoadingNewList = false
    @State var newListName = ""
    @State var isError = false
    @State var initialLoadingList = true
    
    var body: some View {
        if itemListViewModel.listNamesWithIDs.count == 0 && initialLoadingList {
            ProgressView()
            .task {
                pullAvailableLists()
            }
        } else {
            VStack {
                HStack {
                    if isLoadingNewList {
                        ProgressView()
                    }
                    Spacer()
                    if isError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                
                if isError && listNames.count == 0 {
                    Text("Error loading list of items. Check internet connection or server is running.")
                } else {
                    List {
                        HStack {
                            TextField("Create New List", text: $newListName)
                            Spacer()
                            Button {
                                isLoadingNewList = true
                                Task {
                                    if let error = await itemListViewModel.createNewList(listName: newListName) {
                                        isError = true
                                        print(error) // TODO: add metrics
                                    } else {
                                        activeListName = newListName
                                        isError = false
                                        popoverListNames = false
                                    }
                                    isLoadingNewList = false
                                }
                            } label: {
                                Text("Create")
                            }
                            .disabled(newListName.count == 0)
                        }
                        ForEach(listNames, id: \.self) { listName in
                            HStack {
                                Text(listName)
                                Button(action: {
                                    Task {
                                        isLoadingNewList = true
                                        let error = await itemListViewModel.switchList(using: listName)
                                        if let error = error {
                                            print(error)
                                        } else {
                                            activeListName = listName
                                            popoverListNames = false
                                        }
                                        isLoadingNewList = false
                                        
                                    }
                                }) {
                                    
                                }
                                Image(systemName: "xmark.circle.fill")
                                .onTapGesture {
                                    deleteListAndPullRemaining(listName: listName)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .onAppear {
                        pullAvailableLists()
                    }
                }
            }
        }
    }
    
    func deleteListAndPullRemaining(listName: String) {
        isLoadingNewList = true
        Task {
            let result = await itemListViewModel.deleteListName(listName: listName)
            switch result {
            case .success(let listNamesWithIDs):
                var serverListNames: [String] = []
                for item in listNamesWithIDs {
                    serverListNames.append(item.listName)
                }
                activeListName = serverListNames.first ?? ""
                listNames = serverListNames
            case .failure(let error):
                isError = true
                print("TODO \(error)")
            }
            isLoadingNewList = false
        }
    }
    
    func pullAvailableLists() {
        isLoadingNewList = true
        Task {
            let result = await itemListViewModel.pullAvailableLists()
            switch result {
            case .success(let listNamesWithIDs):
                var serverListNames: [String] = []
                for item in listNamesWithIDs {
                    serverListNames.append(item.listName)
                }
                listNames = serverListNames
            case .failure(let error):
                isError = true
                print("TODO \(error)")
            }
            isLoadingNewList = false
            initialLoadingList = false
        }
    }
}

struct UserListNames_Previews: PreviewProvider {
    static var previews: some View {
        UserListNamesView(
            itemListViewModel: ItemListViewModel(),
            popoverListNames: .constant(true),
            activeListName: .constant("")
        )
    }
}
