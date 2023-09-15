//
//  MainScreenView.swift
//  LocalNotes
//
//  Created by krow on 07-03-23.
//

import SwiftUI
import Combine

struct MainTabView: View {
    @State var presentingLoginView = true
    @StateObject var authentication: ConcreteAuthentication = ConcreteAuthentication.shared
    @StateObject var itemListViewModel: ItemListViewModel = ItemListViewModel()
    @State var isAuth = true
    
    @ViewBuilder
    var body: some View {
        if authentication.authenticationState == .notAuthenticated {
            ProgressView()
                .popover(isPresented: $presentingLoginView) {
                LoginView().interactiveDismissDisabled()
            }
        }
        else if authentication.authenticationState == .checking {
            ProgressView()
        }
        else {
            mainScreenView
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
            viewModel: itemListViewModel
        )
        .tabItem {
            Label("Lists", systemImage: "list.bullet")
        }
    }
    
    var settingsTabItem: some View {
        SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gear")
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            MainTabView()
        }
    }
}
