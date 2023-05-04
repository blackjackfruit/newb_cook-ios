//
//  SettingsView.swift
//  LocalNotes
//
//  Created by krow on 07-03-23.
//

import SwiftUI

enum ConnectivityStatus: CustomStringConvertible {
    case none
    case connected
    case not_connected
    
    var description: String {
        return "none"
    }
}

struct SettingsView: View {
    @Binding var isNotAuthenticated: Bool
    
    private var username: String = "empty"
    private var ipAddress: String = "empty"
    private var connectivityStatus: ConnectivityStatus = .none
    private var secureStorage: SecureStorage
    
    @State var confirmationAlert = false
    let settingsViewModel = SettingsViewModel()
    
    init(
        isNotAuthenticated: Binding<Bool>,
        secureStorage: SecureStorage = KeychainStorage()
    ) {
        self._isNotAuthenticated = isNotAuthenticated
        self.secureStorage = secureStorage
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Logged in as:")
                Text(secureStorage.retrieve(key: .username) as? String ?? "Empty")
            }
            VStack {
                List {
                    Section("Network") {
                        HStack {
                            Text("IP Address:")
                            Text("\(settingsViewModel.backendEndpoint() ?? "Error")")
                        }
                    }
                }
            }
            Spacer()
            VStack {
                Button {
                    confirmationAlert = true
                } label: {
                    Text("Log Out")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .alert("Are you sure?", isPresented: $confirmationAlert, actions: {
                    Button(role: .destructive) {
                        settingsViewModel.logout {
                            self.isNotAuthenticated = true
                        }
                    } label: {
                        Text("Log Out")
                    }
                }, message: {
                    Text("You will need to re-authenticate once logged off.")
                })
                .padding(0)
                .background(Color.red)
                .foregroundColor(Color.white)
                
                Circle().frame(height:0)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(isNotAuthenticated: .constant(false))
    }
}
