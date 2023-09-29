//
//  SwiftUIView.swift
//  LocalNotes
//
//  Created by krow on 07-03-23.
//

import SwiftUI
import Combine

fileprivate let loginLoadingColor = Color(UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 0.5))
fileprivate let lightGrayColor = Color.white
fileprivate let gradientColor =
Gradient(colors:
            [
                Color(uiColor: UIColor(red: 0.97, green: 0.44, blue: 0.32, alpha: 1.0)),
                Color(uiColor: UIColor(red: 0.57, green: 0.16, blue: 0.08, alpha: 1.0))
            ]
)

struct LoginView: View {
    @State private var appError: AppError? = nil
    @StateObject var loginViewModel: LoginViewModel = LoginViewModel()
    
    init() {
    }
    
    var body: some View {
        ZStack {
            
            Rectangle()
                .fill(LinearGradient(gradient: gradientColor, startPoint: .top, endPoint: .bottom))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            VStack {
                Image("NewbCookLogo").resizable().scaledToFit().frame(width: 150, height: 150)
                VStack {
                    renderTextFields()
                }

                renderLoginButton()
                if let errorMsg = appError?.description {
                    Text(errorMsg)
                        .foregroundColor(lightGrayColor)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func renderTextFields() -> some View {
        HStack {
            let ipAddress = TextField("URL or IP Address", text: $loginViewModel.hostname)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(lightGrayColor)
            if loginViewModel.isAuthenticatingUser {
                ipAddress
                    .disabled(true)
            }
            else {
                ipAddress
                    .disabled(false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 10, leading: 5, bottom: 10, trailing: 5))
        .background(Color(uiColor: UIColor(red: 0.92, green: 0.45, blue: 0.36, alpha: 0.5)))
        .cornerRadius(5.0)
        
        HStack {
            let usernameTextField = TextField("Username", text: $loginViewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(lightGrayColor)
            if loginViewModel.isAuthenticatingUser {
                usernameTextField
                    .disabled(true)
            }
            else {
                usernameTextField
                    .disabled(false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 10, leading: 5, bottom: 10, trailing: 5))
        .background(Color(uiColor: UIColor(red: 0.92, green: 0.45, blue: 0.36, alpha: 0.5)))
        .cornerRadius(5.0)
        
        HStack {
            let passwordTextField = SecureField("Password", text: $loginViewModel.password)
                .textInputAutocapitalization(.never)
                .foregroundColor(lightGrayColor)
            if loginViewModel.isAuthenticatingUser {
                passwordTextField
                    .disabled(true)
            }
            else {
                passwordTextField
                    .disabled(false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 10, leading: 5, bottom: 10, trailing: 5))
        .background(Color(uiColor: UIColor(red: 0.92, green: 0.45, blue: 0.36, alpha: 0.5)))
        .cornerRadius(5.0)
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
