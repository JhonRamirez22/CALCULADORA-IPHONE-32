// IntegralView.swift
// CalcPrime — MathDF iOS
// Integral solver module — indefinite & definite, step-by-step.

import SwiftUI

struct IntegralView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText = ""
    @State private var variable = "x"
    @State private var isDefinite = false
    @State private var lowerBound = ""
    @State private var upperBound = ""
    @State private var result: CASResult?
    @State private var stepData: [SolutionStepData] = []
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var showGraph = false
    @State private var graphFunctions: [GraphFunction] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Input Section
                inputSection
                
                // Options
                optionsSection
                
                // Solve Button
                solveButton
                
                // Result
                if let result = result {
                    resultSection(result)
                }
                
                // Error
                if let error = errorMessage {
                    errorBanner(error)
                }
                
                // Steps
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.integral.accentColor)
                }
                
                // Graph
                if showGraph && !graphFunctions.isEmpty {
                    graphSection
                }
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Integrales")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                MathKeyboardStrip(text: $inputText, module: .integral)
            }
        }
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Función a integrar")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            
            SmartInputField(
                placeholder: "Ej: sin(x)^2, 1/(x^2+1), e^(2x)*cos(x)",
                text: $inputText,
                onSubmit: solve
            )
        }
    }
    
    // MARK: - Options
    
    private var optionsSection: some View {
        VStack(spacing: 12) {
            // Variable picker
            HStack {
                Text("Variable:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Variable", selection: $variable) {
                    Text("x").tag("x")
                    Text("y").tag("y")
                    Text("t").tag("t")
                    Text("z").tag("z")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
            }
            
            // Definite integral toggle
            Toggle(isOn: $isDefinite) {
                HStack {
                    Image(systemName: "ruler")
                    Text("Integral definida")
                        .font(.subheadline)
                }
            }
            .tint(MathDFColors.accent)
            
            // Bounds
            if isDefinite {
                HStack(spacing: 12) {
                    SmartInputFieldMulti(label: "Desde (a)", placeholder: "0", text: $lowerBound)
                    SmartInputFieldMulti(label: "Hasta (b)", placeholder: "pi", text: $upperBound)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
        .animation(.easeInOut(duration: 0.25), value: isDefinite)
    }
    
    // MARK: - Solve Button
    
    private var solveButton: some View {
        Button(action: solve) {
            HStack(spacing: 8) {
                if isComputing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "function")
                    Text("RESOLVER")
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(inputText.isEmpty ? Color.gray : MathDFColors.accent)
            )
        }
        .disabled(inputText.isEmpty || isComputing)
    }
    
    // MARK: - Result Section
    
    private func resultSection(_ casResult: CASResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(MathDFColors.validGreen)
                Text("Resultado")
                    .font(.headline)
                
                Spacer()
                
                // Copy
                Button(action: {
                    UIPasteboard.general.string = casResult.output.pretty
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
                
                // Graph toggle
                Button(action: { showGraph.toggle() }) {
                    Image(systemName: showGraph ? "chart.xyaxis.line" : "chart.xyaxis.line")
                        .font(.subheadline)
                        .foregroundColor(showGraph ? MathDFColors.accent : .secondary)
                }
            }
            
            // LaTeX result
            MathText(latex: casResult.latex, fontSize: 22)
                .frame(maxWidth: .infinity, minHeight: 50)
            
            // Plain text
            Text(casResult.output.pretty)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.secondary)
            
            if casResult.timeElapsed > 0 {
                Text("Resuelto en \(String(format: "%.3f", casResult.timeElapsed))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MathDFColors.validGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Graph Section
    
    private var graphSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gráfica")
                .font(.headline)
            
            GraphView(
                functions: graphFunctions,
                showSlider: isDefinite,
                sliderLabel: "C"
            )
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(MathDFColors.errorRed)
            Text(message)
                .font(.subheadline)
                .foregroundColor(MathDFColors.errorRed)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MathDFColors.errorRed.opacity(0.08))
        )
    }
    
    // MARK: - Solve Logic
    
    private func solve() {
        guard !inputText.isEmpty else { return }
        
        isComputing = true
        errorMessage = nil
        result = nil
        stepData = []
        graphFunctions = []
        
        let corrected = SmartCorrector.correct(inputText).corrected
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let engine = CASEngine.shared
                let casResult: CASResult
                
                if isDefinite {
                    let a = lowerBound.isEmpty ? "0" : SmartCorrector.correct(lowerBound).corrected
                    let b = upperBound.isEmpty ? "1" : SmartCorrector.correct(upperBound).corrected
                    casResult = engine.integrateDefinite(corrected, variable: variable, from: a, to: b)
                } else {
                    casResult = engine.integrate(corrected, variable: variable)
                }
                
                let steps = SolutionStepData.fromEngineSteps(casResult.steps)
                
                // Build graph functions
                var gFuncs: [GraphFunction] = []
                let inputNode = casResult.input
                let outputNode = casResult.output
                
                gFuncs.append(GraphFunction(
                    label: "f(x)",
                    color: .blue,
                    evaluate: { x, _ in inputNode.evaluate(with: [variable: x]) ?? 0 }
                ))
                
                if !isDefinite {
                    gFuncs.append(GraphFunction(
                        label: "F(x) + C",
                        color: MathDFColors.validGreen,
                        evaluate: { x, c in (outputNode.evaluate(with: [variable: x]) ?? 0) + c },
                        isDashed: true
                    ))
                }
                
                DispatchQueue.main.async {
                    self.result = casResult
                    self.stepData = steps
                    self.graphFunctions = gFuncs
                    self.showGraph = true
                    self.isComputing = false
                    
                    // Save to history
                    let item = HistoryItem(
                        module: .integral,
                        input: inputText,
                        resultLatex: casResult.latex,
                        resultPlain: casResult.output.pretty
                    )
                    appState.addToHistory(item)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        IntegralView()
            .environmentObject(AppState())
    }
}
