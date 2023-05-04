//
//  MainScreenView.swift
//  LocalNotes
//
//  Created by krow on 07-03-23.
//

import SwiftUI

class Authentication: ObservableObject, BackendAPIDelegate {
    @Published var isAuthenticated = false
    func userNotLoggedIn() {
        isAuthenticated = false
    }
}

struct MainTabView: View {
    @ObservedObject var authentication = Authentication()
    @StateObject var itemListViewModel: ItemListViewModel = ItemListViewModel()
    @EnvironmentObject var userAuthentication: UserAuthentication
    @State var isAuth = true
    @Binding var isNotAuthenticated: Bool
    
    var body: some View {
        if isNotAuthenticated {
            ProgressView().popover(isPresented: $isNotAuthenticated) {
                LoginView(isNotAuthenticated: $isNotAuthenticated).interactiveDismissDisabled()
            }
        } else {
            mainScreenView
                .task {
                }
        }
    }
    
    var mainScreenView: some View {
        TabView {
            listTabItem
            settingsTabItem
        }
        // Added this here because toolbar would be transparent when adding custom search bar instead of the searchable modifier
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
    
    var listTabItem: some View {
        ItemListView(
            isNotAuthenticated: $isNotAuthenticated,
            viewModel: itemListViewModel
        )
        .tabItem {
            Label("Lists", systemImage: "list.bullet")
        }
    }
    
    var settingsTabItem: some View {
        SettingsView(isNotAuthenticated: $isNotAuthenticated)
        .tabItem {
            Label("Settings", systemImage: "gear")
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            MainTabView(isNotAuthenticated: .constant(false))
        }
    }
}
