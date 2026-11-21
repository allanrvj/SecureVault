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
    @FocusState private var focusedField: Field?

    let viewModel: AuthViewModel

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                VStack(spacing: 16) {
                    BorderedField {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    BorderedField {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                if canSubmit {
                                    submit()
                                }
                            }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }

                Button(action: submit) {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Log in")
                    }
                }
                .primaryButtonStyle()
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 24)
            .padding(.top, 72)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("SecureVault")
                .font(.largeTitle.bold())
            Text("Sign in to open your vault")
                .foregroundStyle(.secondary)
        }
    }

    private func submit() {
        Task { await viewModel.signIn(email: email, password: password) }
    }

    private var canSubmit: Bool {
        email.isValidEmail && !password.isEmpty && !viewModel.isSubmitting
    }
}

#if DEBUG
    #Preview {
        SignupLoginView(viewModel: .preview)
    }
#endif // DEBUG
