//
//  BorderedField.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 14/10/2026.
//

import SwiftUI

struct BorderedField<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        content
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 15)
    }
}

#Preview {
    @Previewable @State var username = ""
    BorderedField { TextField("Username", text: $username ) }
}
