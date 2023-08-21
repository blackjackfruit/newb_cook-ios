//
//  SearchView.swift
//  LocalNotes
//
//  Created by iury on 4/5/23.
//

import Foundation
import SwiftUI

struct SearchedView: View {
    @FocusState private var focus: FocusField?
    @Binding var isSearching: Bool
    @Binding var searchText: String
    @State private var isSavingToList = false
    @State private var isError = false
    
    var itemListViewModel: ItemListViewModel
    private let lightGray = Color.init(red: 0.95, green: 0.95, blue: 0.95)
    
    var body: some View {
        VStack {
            HStack {
                HStack {
                    TextField("Tap Here to Search for or Add Item", text: $searchText)
                    .focused($focus, equals: .createNewItem)
                    .padding(.leading, 5)
                    .onChange(of: focus) { newValue in
                        if newValue != nil {
                            isSearching = true
                        }
                        else {
                            isSearching = false
                        }
                    }
                    
                    if focus != nil && searchText.count > 0 {
                        if isError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle")
                                .padding(.trailing, 5)
                                .foregroundColor(Color.gray)
                        }
                    }
                }
                .padding(5)
                .cornerRadius(40)
                
                if focus != nil {
                    Button {
                        searchText = ""
                        isSearching = false
                        isError = false
                        focus = nil
                    } label: {
                        Text("Cancel")
                    }
                }
            }
            HStack {
                if focus != nil {
                    Button {
                        isSavingToList = true
                        Task {
                            if let error = await itemListViewModel.addToList(itemName: searchText) {
                                isError = true
                                print("Error \(error)") // TODO: metrics
                            } else {
                                searchText = ""
                            }
                            isSavingToList = false
                        }
                    } label: {
                        if isSavingToList {
                            ProgressView()
                        } else {
                            Text("Add to List")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: 30)
                    .disabled(isSavingToList)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(searchText.count > 0 ? .white : Color.gray)
                    .background(searchText.count > 0 && isSavingToList == false ? Color.blue : lightGray)
                    .padding(1)
                    .cornerRadius(10)
                }
            }
        }
        .padding(10)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchedView(
            isSearching: .constant(true),
            searchText: .constant(""),
            itemListViewModel: ItemListViewModel()
        )
    }
}
