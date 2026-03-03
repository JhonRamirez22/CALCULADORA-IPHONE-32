// ODEView.swift
// CalcPrime — MathDF iOS
// Ordinary Differential Equations solver module.

import SwiftUI

struct ODEView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText = ""
    @State private var initialConditions = ""
    @State private var result: CASResult?
    @State private var stepData: [SolutionStepData] = []
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var showGraph = false
    @State private var graphFunctions: [GraphFunction] = []
    @State private var classificationText: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                inputSection
                optionsSection
                solveButton
                
                if let classification = classificationText {
                    classificationBanner(classification)
                }
                
                if let result = result {
                    resultSection(result)
                }
                
                if let error = errorMessage {
                    errorBanner(error)
                }
                
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.ode.accentColor)
                }
                
                if showGraph && !graphFunctions.isEmpty {
                    graphSection
                }
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ec. Diferenciales")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                MathKeyboardStrip(text: $inputText, module: .ode)
            }
        }
    }
    
    // MARK: - Input
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ecuación Diferencial")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            
            SmartInputField(
                placeholder: "Ej: y' + 2y = sin(x), y'' - y = e^x",
                text: $inputText,
                onSubmit: solve
            )
            
            // Examples
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(odeExamples, id: \.0) { name, expr in
                        Button(action: { inputText = expr }) {
                            Text(name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(MathModule.ode.accentColor.opacity(0.1)))
                                .foregroundColor(MathModule.ode.accentColor)
                        }
                    }
                }
            }
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 12) {
            SmartInputFieldMulti(
                label: "Condiciones iniciales (opcional)",
                placeholder: "Ej: y(0)=1, y'(0)=0",
                text: $initialConditions
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
    }
    
    private var solveButton: some View {
        Button(action: solve) {
            HStack(spacing: 8) {
                if isComputing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "waveform.path.ecg")
                    Text("RESOLVER ODE")
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(inputText.isEmpty ? Color.gray : MathModule.ode.accentColor)
            )
        }
        .disabled(inputText.isEmpty || isComputing)
    }
    
    private func classificationBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .foregroundColor(MathModule.ode.accentColor)
            Text(text)
                .font(.subheadline.bold())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MathModule.ode.accentColor.opacity(0.08))
        )
    }
    
    private func resultSection(_ casResult: CASResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(MathDFColors.validGreen)
                Text("Solución General")
                    .font(.headline)
                Spacer()
                Button(action: { UIPasteboard.general.string = casResult.output.pretty }) {
                    Image(systemName: "doc.on.doc").font(.subheadline)
                }
                .foregroundColor(.secondary)
                Button(action: { showGraph.toggle() }) {
                    Image(systemName: "chart.xyaxis.line").font(.subheadline)
                        .foregroundColor(showGraph ? MathDFColors.accent : .secondary)
                }
            }
            
            MathText(latex: casResult.latex, fontSize: 20)
                .frame(maxWidth: .infinity, minHeight: 50)
            
            Text(casResult.output.pretty)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
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
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(MathDFColors.errorRed)
            Text(message).font(.subheadline).foregroundColor(MathDFColors.errorRed)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(MathDFColors.errorRed.opacity(0.08)))
    }
    
    private var graphSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Campo de direcciones")
                .font(.headline)
            GraphView(functions: graphFunctions, showSlider: true, sliderLabel: "C")
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
        classificationText = nil
        
        let corrected = SmartCorrector.correct(inputText).corrected
        
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = CASEngine.shared
            let casResult = engine.solveODE(corrected)
            let steps = SolutionStepData.fromEngineSteps(casResult.steps)
            
            // Try to classify
            var classification: String? = nil
            if corrected.contains("y''") || corrected.contains("y'2") {
                classification = "ODE de segundo orden"
            } else if corrected.contains("y'") {
                if corrected.contains("y'") && !corrected.contains("y''") {
                    classification = "ODE de primer orden"
                }
            }
            
            // Graph: solution family with C
            var gFuncs: [GraphFunction] = []
            let outputNode = casResult.output
            gFuncs.append(GraphFunction(
                label: "y(x)",
                color: MathModule.ode.accentColor,
                evaluate: { x, c in (outputNode.evaluate(with: ["x": x, "C": c, "C1": c, "c": c]) ?? 0) }
            ))
            
            DispatchQueue.main.async {
                self.result = casResult
                self.stepData = steps
                self.graphFunctions = gFuncs
                self.classificationText = classification
                self.showGraph = true
                self.isComputing = false
                
                appState.addToHistory(HistoryItem(
                    module: .ode, input: inputText,
                    resultLatex: casResult.latex, resultPlain: casResult.output.pretty
                ))
            }
        }
    }
    
    // MARK: - Examples
    
    private let odeExamples: [(String, String)] = [
        ("Separable", "y' = x*y"),
        ("Lineal", "y' + 2y = sin(x)"),
        ("Bernoulli", "y' + y = y^2"),
        ("Exacta", "2xy*dx + x^2*dy = 0"),
        ("2° orden", "y'' - 3y' + 2y = 0"),
    ]
}

#Preview {
    NavigationStack {
        ODEView().environmentObject(AppState())
    }
}
