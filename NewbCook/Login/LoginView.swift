//
//  SwiftUIView.swift
//  LocalNotes
//
//  Created by krow on 07-03-23.
//

import SwiftUI

struct LoginView: View {
    @Binding var isNotAuthenticated: Bool
    
    @State private var ipAddress: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var appError: AppError? = nil
    
    var loginViewModel: LoginViewModel {
        get {
            return LoginViewModel(secureStorage: self.secureStorage, backendAPI: self.backendAPI)
        }
    }
    
    init(isNotAuthenticated: Binding<Bool>) {
        self._isNotAuthenticated = isNotAuthenticated
        self._ipAddress = State(initialValue: loginViewModel.getLastValidEndpoint() ?? "")
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
            Text("Endpoint:")
            let ipAddress = TextField("IP Address", text: $ipAddress)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if isAuthenticating {
                ipAddress.disabled(true)
            }
            else {
                ipAddress.disabled(false)
            }
        }
        HStack {
            Text("Username")
            let usernameTextField = TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if isAuthenticating {
                usernameTextField.disabled(true)
            }
            else {
                usernameTextField.disabled(false)
            }
        }
        HStack {
            Text("Password")
            let passwordTextField = SecureField("Password", text: $password)
                .textInputAutocapitalization(.never)
            if isAuthenticating {
                passwordTextField.disabled(true)
            }
            else {
                passwordTextField.disabled(false)
            }
        }
    }
    
    @ViewBuilder
    func renderLoginButton() -> some View {
        let loginButton = Button {
            self.isAuthenticating = true
            Task {
                let result = await loginViewModel.validateUser(
                    hostname: ipAddress,
                    username: username,
                    password: password
                )
                switch result {
                case .success(_):
                    self.isNotAuthenticated = false
                case .failure(let error):
                    self.isAuthenticating = false
                    self.appError = error
                }
            }
        } label: {
            let loginText = Text("Log In")
                .padding()
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
            self.loginVerification {
                loginText
                    .background(Color(UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)))
            } readyToValidateCredentials: {
                loginText
                    .background(.red)
            } validatingCredentials: {
                ProgressView().padding()
                .frame(maxWidth: .infinity)
                .foregroundColor(.black)
                .background(Color(UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)))
            }
        }
        .cornerRadius(10.0)
        
        self.loginVerification {
            loginButton.disabled(true)
        } readyToValidateCredentials: {
            loginButton.disabled(false)
        } validatingCredentials: {
            loginButton.disabled(true)
        }
    }
    
    @ViewBuilder
    func loginVerification(
        notReadyToValidateCredentials: () -> some View,
        readyToValidateCredentials: () -> some View,
        validatingCredentials: () -> some View
    ) -> some View {
        if (username.count > 0 && password.count > 0) &&
            isAuthenticating == false {
            readyToValidateCredentials()
        }
        else if username.count == 0 || password.count == 0 {
            notReadyToValidateCredentials()
        }
        else {
            validatingCredentials()
        }
    }
}

extension LoginView {
    var secureStorage: SecureStorage {
        get {
            return KeychainStorage.shared
        }
    }
    var backendAPI: BackendAPI {
        get {
            return ConcreteBackendAPI.shared
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isNotAuthenticated: .constant(true))
    }
}
