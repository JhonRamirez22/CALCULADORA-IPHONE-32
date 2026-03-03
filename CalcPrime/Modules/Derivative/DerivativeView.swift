// DerivativeView.swift
// CalcPrime — MathDF iOS
// Derivatives solver — order n, chain rule, implicit differentiation.

import SwiftUI

struct DerivativeView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText = ""
    @State private var variable = "x"
    @State private var order = 1
    @State private var evaluateAt = ""
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
                
                if let result = result {
                    resultSection(result)
                }
                if let error = errorMessage {
                    errorBanner(error)
                }
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.derivative.accentColor)
                }
                if showGraph && !graphFunctions.isEmpty {
                    graphSection
                }
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Derivadas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                MathKeyboardStrip(text: $inputText, module: .derivative)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Función a derivar")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            
            SmartInputField(
                placeholder: "Ej: x^3*sin(x), ln(x^2+1), e^(x^2)",
                text: $inputText,
                onSubmit: solve
            )
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Variable:")
                    .font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $variable) {
                    Text("x").tag("x")
                    Text("y").tag("y")
                    Text("t").tag("t")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                
                Spacer()
                
                Text("Orden:")
                    .font(.subheadline).foregroundColor(.secondary)
                Stepper("\(order)", value: $order, in: 1...10)
                    .frame(width: 120)
            }
            
            SmartInputFieldMulti(
                label: "Evaluar en (opcional)",
                placeholder: "Ej: x=2, x=pi",
                text: $evaluateAt
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
    }
    
    private var solveButton: some View {
        Button(action: solve) {
            HStack(spacing: 8) {
                if isComputing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "divide")
                    Text(order > 1 ? "DERIVADA DE ORDEN \(order)" : "DERIVAR")
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(inputText.isEmpty ? Color.gray : MathModule.derivative.accentColor))
        }
        .disabled(inputText.isEmpty || isComputing)
    }
    
    private func resultSection(_ casResult: CASResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundColor(MathDFColors.validGreen)
                Text(order > 1 ? "Derivada de orden \(order)" : "Derivada")
                    .font(.headline)
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
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.secondary)
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
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Solve
    
    private func solve() {
        guard !inputText.isEmpty else { return }
        isComputing = true
        errorMessage = nil
        result = nil
        stepData = []
        graphFunctions = []
        
        let corrected = SmartCorrector.correct(inputText).corrected
        
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = CASEngine.shared
            
            // Apply derivative N times
            var currentExpr = corrected
            var allSteps: [SolutionStep] = []
            var finalResult: CASResult?
            
            for i in 1...order {
                let casResult = engine.differentiate(currentExpr, variable: variable)
                if i == order { finalResult = casResult }
                allSteps.append(contentsOf: casResult.steps)
                currentExpr = casResult.output.pretty
            }
            
            guard let res = finalResult else {
                DispatchQueue.main.async {
                    errorMessage = "No se pudo calcular la derivada"
                    isComputing = false
                }
                return
            }
            
            let steps = SolutionStepData.fromEngineSteps(allSteps)
            
            // Build graph
            var gFuncs: [GraphFunction] = []
            let inputNode = res.input
            let outputNode = res.output
            
            gFuncs.append(GraphFunction(label: "f(x)", color: .blue,
                evaluate: { x, _ in inputNode.evaluate(with: [variable: x]) ?? 0 }))
            gFuncs.append(GraphFunction(label: "f'(x)", color: .red,
                evaluate: { x, _ in outputNode.evaluate(with: [variable: x]) ?? 0 }, isDashed: true))
            
            DispatchQueue.main.async {
                self.result = res
                self.stepData = steps
                self.graphFunctions = gFuncs
                self.showGraph = true
                self.isComputing = false
                
                appState.addToHistory(HistoryItem(
                    module: .derivative, input: inputText,
                    resultLatex: res.latex, resultPlain: res.output.pretty
                ))
            }
        }
    }
}

#Preview {
    NavigationStack {
        DerivativeView().environmentObject(AppState())
    }
}
