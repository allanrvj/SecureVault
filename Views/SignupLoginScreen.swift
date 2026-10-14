//
//  SignupLoginView.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 13/10/2026.
//

import SwiftUI

struct SignupLoginScreen: View {
    
    @State var username = ""
    @State var password = ""
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack {
                Text("SecureVault").font(.title2).foregroundStyle(Color.accentColor).padding().bold()
                
                Spacer()
                
                Text("Welcome back").font(.title).padding(50)

                BorderedField {
                    TextField("Username", text: $username)
                }
                
                BorderedField {
                    SecureField("Password", text: $password)
                }

                
                Button(action: {}) {
                    Text("Login to system")
                }.buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .shadow(radius: 3)
                    .padding()
                
                Spacer()
            }
 
        }
    }
}

#Preview {
    SignupLoginScreen()
}
