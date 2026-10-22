//
//  AppConfig.swift
//  SecureVault
//
//  Created by Allan Ray Jasa on 22/10/2026.
//

import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String,
              !host.isEmpty,
              let url = URL(string: "https://\(host)") else {
            fatalError("Missing SUPABASE_HOST. Copy Secrets.example.xcconfig to Secrets.xcconfig and fill it in.")
        }
        return url
    }()
    
    static let supabaseKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String,
              !key.isEmpty else {
            fatalError("Missing SUPABASE_KEY. See README.")
        }
        return key
    }()
}
