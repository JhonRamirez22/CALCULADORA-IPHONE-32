// MathDFApp.swift
// CalcPrime — MathDF iOS
// App entry point — MathDF-inspired mathematical solver for iPhone.
// Bundle ID: com.personal.mathdfios · iOS 17+ · SwiftUI

import SwiftUI

@main
struct MathDFApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
        }
    }
}
