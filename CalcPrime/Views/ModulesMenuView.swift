// ModulesMenuView.swift
// CalcPrime — Views
// Module selection menu for specialized calculator modes.

import SwiftUI

struct ModulesMenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModule: CalculatorModule?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(CalculatorModule.allCases) { module in
                        ModuleCard(module: module) {
                            selectedModule = module
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "0A0A0F"))
            .navigationTitle("Módulos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(item: $selectedModule) { module in
                moduleView(for: module)
            }
        }
    }
    
    @ViewBuilder
    private func moduleView(for module: CalculatorModule) -> some View {
        switch module {
        case .derivatives: DerivativeModuleView(appState: appState)
        case .integrals: IntegralModuleView(appState: appState)
        case .equations: EquationModuleView(appState: appState)
        case .factorization: FactorizationModuleView(appState: appState)
        case .ode: ODEModuleView(appState: appState)
        case .pde: PDEModuleView(appState: appState)
        case .linearAlgebra: LinearAlgebraModuleView(appState: appState)
        case .series: SeriesModuleView(appState: appState)
        case .transforms: TransformModuleView(appState: appState)
        case .numerical: NumericalModuleView(appState: appState)
        case .specialFunctions: SpecialFunctionsModuleView(appState: appState)
        case .identities: IdentitiesModuleView(appState: appState)
        }
    }
}

// MARK: - CalculatorModule

enum CalculatorModule: String, CaseIterable, Identifiable {
    case derivatives       = "Derivadas"
    case integrals         = "Integrales"
    case equations         = "Ecuaciones"
    case factorization     = "Factorización"
    case ode               = "EDOs"
    case pde               = "EDPs"
    case linearAlgebra     = "Álgebra Lineal"
    case series            = "Series"
    case transforms        = "Transformadas"
    case numerical         = "Métodos Numéricos"
    case specialFunctions  = "Funciones Especiales"
    case identities        = "Identidades"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .derivatives: return "arrow.up.right"
        case .integrals: return "sum"
        case .equations: return "equal"
        case .factorization: return "square.grid.2x2"
        case .ode: return "waveform.path.ecg"
        case .pde: return "square.3.layers.3d"
        case .linearAlgebra: return "square.grid.3x3"
        case .series: return "ellipsis"
        case .transforms: return "arrow.left.arrow.right"
        case .numerical: return "number"
        case .specialFunctions: return "function"
        case .identities: return "textformat.abc"
        }
    }
    
    var color: Color {
        switch self {
        case .derivatives: return .orange
        case .integrals: return .blue
        case .equations: return .green
        case .factorization: return .purple
        case .ode: return .red
        case .pde: return .pink
        case .linearAlgebra: return .cyan
        case .series: return .yellow
        case .transforms: return .mint
        case .numerical: return .teal
        case .specialFunctions: return .indigo
        case .identities: return .brown
        }
    }
    
    var description: String {
        switch self {
        case .derivatives: return "Derivadas parciales y de orden n"
        case .integrals: return "Integrales definidas e indefinidas"
        case .equations: return "Resolver ecuaciones y sistemas"
        case .factorization: return "Factorizar polinomios y expresiones"
        case .ode: return "Ecuaciones diferenciales ordinarias"
        case .pde: return "Ecuaciones en derivadas parciales"
        case .linearAlgebra: return "Matrices, determinantes, eigenvalores"
        case .series: return "Taylor, Fourier, convergencia"
        case .transforms: return "Laplace, Fourier, Z"
        case .numerical: return "Newton, Simpson, Runge-Kutta"
        case .specialFunctions: return "Bessel, Gamma, erf, Airy..."
        case .identities: return "Identidades trigonométricas"
        }
    }
}

// MARK: - Module Card

struct ModuleCard: View {
    let module: CalculatorModule
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: module.icon)
                    .font(.system(size: 28))
                    .foregroundColor(module.color)
                
                Text(module.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(module.description)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(module.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
