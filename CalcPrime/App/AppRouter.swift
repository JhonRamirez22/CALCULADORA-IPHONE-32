// AppRouter.swift
// CalcPrime — MathDF iOS
// Navigation: Home → Modules. Uses NavigationStack for clean push transitions.

import SwiftUI

struct AppRouter: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            HomeView()
                .navigationDestination(for: MathModule.self) { module in
                    moduleView(for: module)
                }
                .navigationDestination(for: String.self) { route in
                    stringRoute(route)
                }
        }
        .tint(MathDFColors.accent)
    }
    
    @ViewBuilder
    private func moduleView(for module: MathModule) -> some View {
        switch module {
        case .integral:
            IntegralView()
        case .ode:
            ODEView()
        case .derivative:
            DerivativeView()
        case .equation:
            EquationView()
        case .limit:
            LimitView()
        case .matrix:
            MatrixView()
        case .complex:
            ComplexView()
        case .numeric:
            NumericView()
        }
    }
    
    @ViewBuilder
    private func stringRoute(_ route: String) -> some View {
        switch route {
        case "history":
            HistoryView()
        case "settings":
            SettingsView()
        default:
            Text("Ruta no encontrada")
        }
    }
}
