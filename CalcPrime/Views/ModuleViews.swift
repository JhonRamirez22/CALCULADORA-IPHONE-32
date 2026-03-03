// ModuleViews.swift
// CalcPrime — Views/Modules
// Individual module views for each specialized calculator mode.
// Each provides a dedicated input interface for its mathematical domain.

import SwiftUI

// ═══════════════════════════════════════════════
// MARK: - Derivative Module
// ═══════════════════════════════════════════════

struct DerivativeModuleView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var expression = ""
    @State private var variable = "x"
    @State private var order = 1
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Derivadas", icon: "arrow.up.right", color: .orange) {
                Section("Expresión") {
                    TextField("f(x) = ...", text: $expression)
                        .font(.system(.body, design: .monospaced))
                    
                    HStack {
                        Text("Variable:")
                        TextField("x", text: $variable)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        
                        Spacer()
                        
                        Text("Orden:")
                        Stepper("\(order)", value: $order, in: 1...10)
                            .frame(width: 120)
                    }
                }
                
                Section {
                    calculateButton {
                        let input = order > 1 ? "d\(order)/d\(variable)\(order) \(expression)" : "d/d\(variable) \(expression)"
                        evaluate(input, category: .derivative)
                    }
                }
                
                resultSection
            }
        }
    }
    
    private var resultSection: some View {
        Group {
            if let r = result {
                Section("Resultado") {
                    ResultCard(result: r)
                }
            }
        }
    }
    
    private func evaluate(_ input: String, category: CalculationCategory) {
        do {
            let cas = try appState.engine.process(input)
            result = CalculationResult.from(cas, category: category)
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Integral Module
// ═══════════════════════════════════════════════

struct IntegralModuleView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var expression = ""
    @State private var variable = "x"
    @State private var isDefinite = false
    @State private var lowerBound = "0"
    @State private var upperBound = "1"
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Integrales", icon: "sum", color: .blue) {
                Section("Expresión") {
                    TextField("f(x) = ...", text: $expression)
                        .font(.system(.body, design: .monospaced))
                    
                    HStack {
                        Text("Variable:")
                        TextField("x", text: $variable)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Toggle("Integral definida", isOn: $isDefinite)
                    
                    if isDefinite {
                        HStack {
                            Text("De:")
                            TextField("a", text: $lowerBound)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                            Text("a:")
                            TextField("b", text: $upperBound)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                Section {
                    calculateButton {
                        let input = isDefinite
                            ? "∫(\(lowerBound),\(upperBound)) \(expression) d\(variable)"
                            : "∫ \(expression) d\(variable)"
                        evaluate(input, category: .integral)
                    }
                }
                
                if let r = result {
                    Section("Resultado") { ResultCard(result: r) }
                }
            }
        }
    }
    
    private func evaluate(_ input: String, category: CalculationCategory) {
        do {
            let cas = try appState.engine.process(input)
            result = CalculationResult.from(cas, category: category)
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Equation Module
// ═══════════════════════════════════════════════

struct EquationModuleView: View {
    @ObservedObject var appState: AppState
    @State private var equation = ""
    @State private var variable = "x"
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Ecuaciones", icon: "equal", color: .green) {
                Section("Ecuación") {
                    TextField("f(x) = 0", text: $equation)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Text("Resolver para:")
                        TextField("x", text: $variable)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Section {
                    calculateButton {
                        do {
                            let cas = try appState.engine.process("solve(\(equation), \(variable))")
                            result = CalculationResult.from(cas, category: .equation)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
                if let r = result {
                    Section("Soluciones") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Factorization Module
// ═══════════════════════════════════════════════

struct FactorizationModuleView: View {
    @ObservedObject var appState: AppState
    @State private var expression = ""
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Factorización", icon: "square.grid.2x2", color: .purple) {
                Section("Expresión") {
                    TextField("x² - 4", text: $expression)
                        .font(.system(.body, design: .monospaced))
                }
                Section {
                    calculateButton {
                        do {
                            let cas = try appState.engine.process("factor(\(expression))")
                            result = CalculationResult.from(cas, category: .factorization)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
                if let r = result {
                    Section("Factorización") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - ODE Module
// ═══════════════════════════════════════════════

struct ODEModuleView: View {
    @ObservedObject var appState: AppState
    @State private var equation = ""
    @State private var functionVar = "y"
    @State private var independentVar = "x"
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "EDOs", icon: "waveform.path.ecg", color: .red) {
                Section("Ecuación Diferencial") {
                    TextField("y' + 2y = e^x", text: $equation)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Text("Función:")
                        TextField("y", text: $functionVar)
                            .frame(width: 50).textFieldStyle(.roundedBorder)
                        Text("Variable:")
                        TextField("x", text: $independentVar)
                            .frame(width: 50).textFieldStyle(.roundedBorder)
                    }
                }
                
                Section("Tipos soportados") {
                    ForEach([ODEType.separable, .linear1stOrder, .exact, .bernoulli,
                             .linear2ndConst, .cauchyEuler], id: \.rawValue) { type in
                        HStack {
                            Text(type.rawValue)
                                .font(.system(size: 13))
                            Spacer()
                            Text(type.methods.first ?? "")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section {
                    calculateButton {
                        do {
                            let cas = try appState.engine.process("ode(\(equation))")
                            result = CalculationResult.from(cas, category: .ode)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
                
                if let r = result {
                    Section("Solución") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - PDE Module
// ═══════════════════════════════════════════════

struct PDEModuleView: View {
    @ObservedObject var appState: AppState
    @State private var equation = ""
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "EDPs", icon: "square.3.layers.3d", color: .pink) {
                Section("Ecuación en Derivadas Parciales") {
                    TextField("∂u/∂t = α²·∂²u/∂x²", text: $equation)
                        .font(.system(.body, design: .monospaced))
                }
                Section("Tipos soportados") {
                    Text("• Ecuación del calor (Dirichlet/Neumann)")
                    Text("• Ecuación de onda")
                    Text("• Ecuación de Laplace")
                    Text("• Ecuación de Poisson")
                    Text("• Método de d'Alembert")
                    Text("• Método de características")
                }
                .font(.system(size: 13))
                .foregroundColor(.gray)
                
                Section {
                    calculateButton {
                        // PDE processing
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Linear Algebra Module
// ═══════════════════════════════════════════════

struct LinearAlgebraModuleView: View {
    @ObservedObject var appState: AppState
    @State private var matrixInput = ""
    @State private var operation = "determinant"
    @State private var result: CalculationResult?
    
    let operations = [
        ("determinant", "Determinante"),
        ("inverse", "Inversa"),
        ("eigenvalues", "Eigenvalores"),
        ("eigenvectors", "Eigenvectores"),
        ("rref", "Forma escalonada (RREF)"),
        ("rank", "Rango"),
        ("lu", "Descomposición LU"),
        ("qr", "Descomposición QR"),
        ("svd", "SVD"),
    ]
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Álgebra Lineal", icon: "square.grid.3x3", color: .cyan) {
                Section("Matriz (formato: [[1,2],[3,4]])") {
                    TextField("[[1,2],[3,4]]", text: $matrixInput)
                        .font(.system(.body, design: .monospaced))
                }
                Section("Operación") {
                    Picker("Operación", selection: $operation) {
                        ForEach(operations, id: \.0) { op in
                            Text(op.1).tag(op.0)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    calculateButton {
                        do {
                            let cas = try appState.engine.process("\(operation)(\(matrixInput))")
                            result = CalculationResult.from(cas, category: .linearAlgebra)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
                if let r = result {
                    Section("Resultado") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Series Module
// ═══════════════════════════════════════════════

struct SeriesModuleView: View {
    @ObservedObject var appState: AppState
    @State private var expression = ""
    @State private var variable = "x"
    @State private var center = "0"
    @State private var order = 5
    @State private var seriesType = "taylor"
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Series", icon: "ellipsis", color: .yellow) {
                Section("Expresión") {
                    TextField("f(x) = ...", text: $expression)
                        .font(.system(.body, design: .monospaced))
                    Picker("Tipo", selection: $seriesType) {
                        Text("Taylor").tag("taylor")
                        Text("Maclaurin").tag("maclaurin")
                        Text("Laurent").tag("laurent")
                        Text("Fourier").tag("fourier")
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("Centro:")
                        TextField("0", text: $center)
                            .frame(width: 50).textFieldStyle(.roundedBorder)
                        Spacer()
                        Stepper("Orden: \(order)", value: $order, in: 1...20)
                    }
                }
                Section {
                    calculateButton {
                        let input = "taylor(\(expression), \(variable), \(center), \(order))"
                        do {
                            let cas = try appState.engine.process(input)
                            result = CalculationResult.from(cas, category: .series)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
                if let r = result {
                    Section("Expansión") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Transform Module
// ═══════════════════════════════════════════════

struct TransformModuleView: View {
    @ObservedObject var appState: AppState
    @State private var expression = ""
    @State private var transformType = "laplace"
    @State private var isInverse = false
    @State private var result: CalculationResult?
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Transformadas", icon: "arrow.left.arrow.right", color: .mint) {
                Section("Expresión") {
                    TextField("f(t) = ...", text: $expression)
                        .font(.system(.body, design: .monospaced))
                    Picker("Tipo", selection: $transformType) {
                        Text("Laplace").tag("laplace")
                        Text("Fourier").tag("fourier")
                        Text("Z").tag("z")
                    }
                    .pickerStyle(.segmented)
                    Toggle("Inversa", isOn: $isInverse)
                }
                Section {
                    calculateButton {
                        let cmd = isInverse ? "inverse_\(transformType)" : transformType
                        do {
                            let cas = try appState.engine.process("\(cmd)(\(expression))")
                            result = CalculationResult.from(cas, category: .transform)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
                if let r = result {
                    Section("Transformada") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Numerical Module
// ═══════════════════════════════════════════════

struct NumericalModuleView: View {
    @ObservedObject var appState: AppState
    @State private var method = "newton"
    @State private var expression = ""
    @State private var x0 = "1.0"
    @State private var result: CalculationResult?
    
    let methods = [
        ("newton", "Newton-Raphson"),
        ("bisection", "Bisección"),
        ("secant", "Secante"),
        ("brent", "Brent"),
        ("simpson", "Simpson"),
        ("rk4", "Runge-Kutta 4"),
    ]
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Métodos Numéricos", icon: "number", color: .teal) {
                Section("Método") {
                    Picker("Método", selection: $method) {
                        ForEach(methods, id: \.0) { m in
                            Text(m.1).tag(m.0)
                        }
                    }
                }
                Section("Parámetros") {
                    TextField("f(x) = ...", text: $expression)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Text("x₀:")
                        TextField("1.0", text: $x0)
                            .frame(width: 80).textFieldStyle(.roundedBorder)
                    }
                }
                Section {
                    calculateButton {
                        // Numerical method evaluation
                    }
                }
                if let r = result {
                    Section("Resultado") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Special Functions Module
// ═══════════════════════════════════════════════

struct SpecialFunctionsModuleView: View {
    @ObservedObject var appState: AppState
    @State private var selectedFunction = "gamma"
    @State private var argument = ""
    @State private var result: CalculationResult?
    
    let functions = [
        ("gamma", "Γ(x) — Gamma"),
        ("beta", "B(a,b) — Beta"),
        ("erf", "erf(x) — Error"),
        ("besselJ", "Jₙ(x) — Bessel 1ᵃ especie"),
        ("besselY", "Yₙ(x) — Bessel 2ᵃ especie"),
        ("airyAi", "Ai(x) — Airy"),
        ("legendreP", "Pₙ(x) — Legendre"),
        ("hermiteH", "Hₙ(x) — Hermite"),
        ("chebyshevT", "Tₙ(x) — Chebyshev"),
        ("lambertW", "W(x) — Lambert W"),
        ("zeta", "ζ(s) — Riemann Zeta"),
        ("ellipticK", "K(k) — Elíptica completa"),
    ]
    
    var body: some View {
        NavigationView {
            moduleForm(title: "Funciones Especiales", icon: "function", color: .indigo) {
                Section("Función") {
                    Picker("Función", selection: $selectedFunction) {
                        ForEach(functions, id: \.0) { f in
                            Text(f.1).tag(f.0)
                        }
                    }
                }
                Section("Argumento(s)") {
                    TextField("x = ...", text: $argument)
                        .font(.system(.body, design: .monospaced))
                }
                Section {
                    calculateButton {
                        do {
                            let cas = try appState.engine.process("\(selectedFunction)(\(argument))")
                            result = CalculationResult.from(cas, category: .general)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
                if let r = result {
                    Section("Resultado") { ResultCard(result: r) }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Identities Module
// ═══════════════════════════════════════════════

struct IdentitiesModuleView: View {
    @ObservedObject var appState: AppState
    @State private var selectedCategory: IdentityCategory = .pythagorean
    
    var body: some View {
        NavigationView {
            List {
                Picker("Categoría", selection: $selectedCategory) {
                    ForEach(IdentityCategory.allCases, id: \.rawValue) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                
                let refs = TrigIdentities.referenceTable.filter { $0.category == selectedCategory }
                ForEach(refs, id: \.name) { identity in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(identity.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        MathJaxInlineView(
                            latex: identity.latex,
                            textColor: "#FFB300",
                            fontSize: 16
                        )
                        .frame(height: 32)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Identidades")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - Shared Components
// ═══════════════════════════════════════════════

// Result display card
struct ResultCard: View {
    let result: CalculationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.latex.isEmpty {
                MathJaxView(
                    latex: result.latex,
                    textColor: "#FFB300",
                    fontSize: 18,
                    backgroundColor: "#111111"
                )
                .frame(height: 50)
            }
            
            Text(result.output)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .textSelection(.enabled)
            
            if result.timeElapsed > 0 {
                Text(String(format: "Tiempo: %.4fs", result.timeElapsed))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
    }
}

// Reusable module form wrapper
struct ModuleFormContent<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form { content }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cerrar") { dismiss() }
            }
        }
    }
}

extension View {
    func moduleForm<Content: View>(title: String, icon: String, color: Color,
                                     @ViewBuilder content: () -> Content) -> some View {
        ModuleFormContent(title: title, icon: icon, color: color, content: content)
    }
    
    func calculateButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                Image(systemName: "play.fill")
                Text("Calcular")
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .background(Color.orange)
            .cornerRadius(10)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}
