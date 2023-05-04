//
//  RowView.swift
//  LocalNotes
//
//  Created by krow on 13-03-23.
//

import SwiftUI

struct RowView: View {

    var sectionWithEntry: ListSectionWithEntry
    var itemListViewModel: ItemListViewModel
    
    var body: some View {
        HStack {
            Image(
                systemName: sectionWithEntry.entryIsCheckMarked ? "checkmark.circle" : "circle"
            )
            .onTapGesture {
                let l_sectionWithEntry = ListSectionWithEntry(
                    listID: sectionWithEntry.listID,
                    listName: sectionWithEntry.listName,
                    sectionID: sectionWithEntry.sectionID,
                    sectionName: sectionWithEntry.sectionName,
                    sectionType: sectionWithEntry.sectionType,
                    entryID: sectionWithEntry.entryID,
                    entryName: sectionWithEntry.entryName,
                    entryIsCheckMarked: !sectionWithEntry.entryIsCheckMarked
                )
                if sectionWithEntry.entryIsCheckMarked {
                    Task {
                        await itemListViewModel.updateEntry(sectionWithEntry: l_sectionWithEntry)
                    }
                } else {
                    Task {
                        await itemListViewModel.updateEntry(sectionWithEntry: l_sectionWithEntry)
                    }
                }
            }
            .frame(width: 30)
            Text(sectionWithEntry.entryName)
            Spacer()
        }
    }
}


#if DEBUG

//struct RowView_Previews: PreviewProvider {
//    static var previews: some View {
//        RowView(
//            sectionWithEntry: .constant(ListSectionWithEntry(
//                section_name: "sectionName",
//                entry_name: "entryName",
//                entry_is_check_marked: true),
//            itemListViewModel: ItemListViewModel()
//        )
//        )
//    }
//}

#endif
