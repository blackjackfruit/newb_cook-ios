//
//  SwiftUIView.swift
//  LocalNotes
//
//  Created by krow on 07-03-23.
//

import SwiftUI
import Combine

fileprivate let loginLoadingColor = Color(UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0))
fileprivate let lightGrayColor = Color(UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))

struct LoginView: View {
    @State private var appError: AppError? = nil
    @StateObject var loginViewModel: LoginViewModel = LoginViewModel()
    
    init() {
    }
    
    var body: some View {
        ZStack {
            VStack {
                VStack {
                    renderTextFields()
                }
                .padding(.all)
                renderLoginButton()
                if let errorMsg = appError?.description {
                    Text(errorMsg)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func renderTextFields() -> some View {
        HStack {
            Text("Host:")
            let ipAddress = TextField("URL or IP Address", text: $loginViewModel.hostname)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if loginViewModel.isAuthenticatingUser {
                ipAddress
                    .disabled(true)
                    .foregroundColor(lightGrayColor)
            }
            else {
                ipAddress
                    .disabled(false)
                    .foregroundColor(.black)
            }
        }
        HStack {
            Text("Username")
            let usernameTextField = TextField("Username", text: $loginViewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if loginViewModel.isAuthenticatingUser {
                usernameTextField
                    .disabled(true)
                    .foregroundColor(lightGrayColor)
            }
            else {
                usernameTextField
                    .disabled(false)
                    .foregroundColor(.black)
            }
        }
        HStack {
            Text("Password")
            let passwordTextField = SecureField("Password", text: $loginViewModel.password)
                .textInputAutocapitalization(.never)
            if loginViewModel.isAuthenticatingUser {
                passwordTextField
                    .disabled(true)
                    .foregroundColor(lightGrayColor)
            }
            else {
                passwordTextField
                    .disabled(false)
                    .foregroundColor(.black)
            }
        }
    }
    
    @ViewBuilder
    func renderLoginButton() -> some View {
        let loginButton = Button {
            Task {
                loginViewModel.validateUser { appError in
                    self.appError = appError
                }
            }
        } label: {
            if loginViewModel.isAuthenticatingUser {
                ProgressView()
                    .padding()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .background(loginLoadingColor)
            } else {
                let loginText = Text("Log In")
                    .padding()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                if loginViewModel.allFieldsValid {
                    loginText
                        .background(.red)
                } else {
                    loginText
                        .background(loginLoadingColor)
                }
            }
        }
        .cornerRadius(10.0)
        
        if loginViewModel.isAuthenticatingUser || loginViewModel.allFieldsValid == false {
            loginButton.disabled(true)
        }
        else {
            loginButton.disabled(false)
        }
    }
}

extension LoginView {
    var storage: Storage {
        get {
            return KeychainStorage.shared
        }
    }
    var endpointCommunication: EndpointCommunication {
        get {
            return ConcreteEndpointCommunication.shared
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
