//
//  SignupLoginView.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 13/10/2026.
//

import SwiftUI

struct SignupLoginView: View {
    
    @State private var email = ""
    @State private var password = ""
    
    private let viewModel: AuthViewModel
    
    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
            VStack {
                Text("SecureVault").font(.title2).foregroundStyle(Color.accentColor).padding().bold()
                
                Spacer()
                
                Text("Welcome back").font(.title).padding(50)

                BorderedField {
                    TextField("Email", text: $email)
                }
                
                BorderedField {
                    SecureField("Password", text: $password)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    Task {
                        await viewModel.signIn(email: email, password: password)
                    }
                }) {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Login to system")
                    }
                }.buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .shadow(radius: 3)
                    .padding()
                    .disabled(!canSubmit)
                
                Spacer()
            }
 
        }
    }
    
    private var canSubmit: Bool {
        email.isValidEmail && !password.isEmpty
    }
}

#if DEBUG
#Preview {
    SignupLoginView(viewModel: .preview)
}
#endif // DEBUG
