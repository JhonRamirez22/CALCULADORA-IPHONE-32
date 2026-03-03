// EquationView.swift
// CalcPrime — MathDF iOS
// Equation solver — polynomials, transcendentals, systems.

import SwiftUI

struct EquationView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText = ""
    @State private var variable = "x"
    @State private var result: CASResult?
    @State private var stepData: [SolutionStepData] = []
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var showGraph = false
    @State private var graphFunctions: [GraphFunction] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                inputSection
                optionsSection
                solveButton
                
                if let result = result { resultSection(result) }
                if let error = errorMessage { errorBanner(error) }
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.equation.accentColor)
                }
                if showGraph && !graphFunctions.isEmpty { graphSection }
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ecuaciones")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                MathKeyboardStrip(text: $inputText, module: .equation)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ecuación")
                .font(.subheadline.bold()).foregroundColor(.secondary)
            
            SmartInputField(
                placeholder: "Ej: x^2 - 5x + 6 = 0, sin(x) = 0.5",
                text: $inputText,
                onSubmit: solve
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examples, id: \.0) { name, expr in
                        Button(action: { inputText = expr }) {
                            Text(name).font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(MathModule.equation.accentColor.opacity(0.1)))
                                .foregroundColor(MathModule.equation.accentColor)
                        }
                    }
                }
            }
        }
    }
    
    private var optionsSection: some View {
        HStack {
            Text("Variable:").font(.subheadline).foregroundColor(.secondary)
            Picker("", selection: $variable) {
                Text("x").tag("x"); Text("y").tag("y"); Text("z").tag("z")
            }
            .pickerStyle(.segmented).frame(width: 160)
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
    }
    
    private var solveButton: some View {
        Button(action: solve) {
            HStack(spacing: 8) {
                if isComputing { ProgressView().tint(.white) }
                else {
                    Image(systemName: "equal.circle")
                    Text("RESOLVER").fontWeight(.bold)
                }
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(inputText.isEmpty ? Color.gray : MathModule.equation.accentColor))
        }
        .disabled(inputText.isEmpty || isComputing)
    }
    
    private func resultSection(_ casResult: CASResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundColor(MathDFColors.validGreen)
                Text("Soluciones").font(.headline)
                Spacer()
                Button(action: { UIPasteboard.general.string = casResult.output.pretty }) {
                    Image(systemName: "doc.on.doc").font(.subheadline)
                }.foregroundColor(.secondary)
                Button(action: { showGraph.toggle() }) {
                    Image(systemName: "chart.xyaxis.line").font(.subheadline)
                        .foregroundColor(showGraph ? MathDFColors.accent : .secondary)
                }
            }
            
            MathText(latex: casResult.latex, fontSize: 22)
                .frame(maxWidth: .infinity, minHeight: 50)
            
            Text(casResult.output.pretty)
                .font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MathDFColors.validGreen.opacity(0.3), lineWidth: 1))
        )
    }
    
    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(MathDFColors.errorRed)
            Text(msg).font(.subheadline).foregroundColor(MathDFColors.errorRed)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(MathDFColors.errorRed.opacity(0.08)))
    }
    
    private var graphSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gráfica").font(.headline)
            GraphView(functions: graphFunctions, showSlider: false)
                .frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Solve
    
    private func solve() {
        guard !inputText.isEmpty else { return }
        isComputing = true; errorMessage = nil; result = nil; stepData = []; graphFunctions = []
        
        let corrected = SmartCorrector.correct(inputText).corrected
        
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = CASEngine.shared
            let casResult = engine.solve(corrected, variable: variable)
            let steps = SolutionStepData.fromEngineSteps(casResult.steps)
            
            // Graph: plot f(x) = left - right so roots are x-intercepts
            var gFuncs: [GraphFunction] = []
            let node = casResult.input
            gFuncs.append(GraphFunction(label: "f(x)", color: MathModule.equation.accentColor,
                evaluate: { x, _ in node.evaluate(with: [variable: x]) ?? 0 }))
            // y=0 line
            gFuncs.append(GraphFunction(label: "y=0", color: .gray,
                evaluate: { _, _ in 0 }, isDashed: true))
            
            DispatchQueue.main.async {
                self.result = casResult; self.stepData = steps
                self.graphFunctions = gFuncs; self.showGraph = true; self.isComputing = false
                appState.addToHistory(HistoryItem(module: .equation, input: inputText,
                    resultLatex: casResult.latex, resultPlain: casResult.output.pretty))
            }
        }
    }
    
    private let examples: [(String, String)] = [
        ("Cuadrática", "x^2 - 5x + 6 = 0"),
        ("Cúbica", "x^3 - 6x^2 + 11x - 6 = 0"),
        ("Trigonométrica", "sin(x) = 1/2"),
        ("Exponencial", "e^x = 5"),
        ("Logarítmica", "ln(x) + ln(x-1) = 1"),
    ]
}

#Preview {
    NavigationStack { EquationView().environmentObject(AppState()) }
}
