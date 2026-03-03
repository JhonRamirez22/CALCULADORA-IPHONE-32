// CalcPrimeApp.swift
// CalcPrime — App Entry Point
// HP Prime G2-inspired scientific calculator with CAS.

import SwiftUI

@main
struct CalcPrimeApp: App {
    
    var body: some Scene {
        WindowGroup {
            MainCalculatorView()
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
    }
}
