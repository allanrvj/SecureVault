//
//  SwiftUIView.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 01/11/2026.
//

import SwiftUI

extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(.borderedProminent)
            .controlSize(.large)
            .shadow(radius: 3)
    }
}
