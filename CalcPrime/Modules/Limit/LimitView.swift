// LimitView.swift
// CalcPrime — MathDF iOS
// Limits solver — L'Hôpital, notable limits, Taylor expansion.

import SwiftUI

struct LimitView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText = ""
    @State private var variable = "x"
    @State private var pointText = "0"
    @State private var direction: LimitDirection = .both
    @State private var result: CASResult?
    @State private var stepData: [SolutionStepData] = []
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var showGraph = false
    @State private var graphFunctions: [GraphFunction] = []
    
    enum LimitDirection: String, CaseIterable {
        case both = "Bilateral"
        case left = "Por izquierda (⁻)"
        case right = "Por derecha (⁺)"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                inputSection
                optionsSection
                solveButton
                
                if let result = result { resultSection(result) }
                if let error = errorMessage { errorBanner(error) }
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.limit.accentColor)
                }
                if showGraph && !graphFunctions.isEmpty { graphSection }
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Límites")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                MathKeyboardStrip(text: $inputText, module: .limit)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Función")
                .font(.subheadline.bold()).foregroundColor(.secondary)
            
            SmartInputField(
                placeholder: "Ej: sin(x)/x, (1+1/x)^x, (e^x-1)/x",
                text: $inputText,
                onSubmit: solve
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(limitExamples, id: \.0) { name, expr, pt in
                        Button(action: { inputText = expr; pointText = pt }) {
                            Text(name).font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(MathModule.limit.accentColor.opacity(0.1)))
                                .foregroundColor(MathModule.limit.accentColor)
                        }
                    }
                }
            }
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Variable:").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $variable) {
                    Text("x").tag("x"); Text("n").tag("n"); Text("t").tag("t")
                }.pickerStyle(.segmented).frame(width: 150)
                Spacer()
            }
            
            SmartInputFieldMulti(label: "Punto (\(variable) →)", placeholder: "0, inf, pi", text: $pointText)
            
            Picker("Dirección", selection: $direction) {
                ForEach(LimitDirection.allCases, id: \.self) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
    }
    
    private var solveButton: some View {
        Button(action: solve) {
            HStack(spacing: 8) {
                if isComputing { ProgressView().tint(.white) }
                else {
                    Image(systemName: "arrow.right")
                    Text("CALCULAR LÍMITE").fontWeight(.bold)
                }
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(inputText.isEmpty ? Color.gray : MathModule.limit.accentColor))
        }
        .disabled(inputText.isEmpty || isComputing)
    }
    
    private func resultSection(_ casResult: CASResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundColor(MathDFColors.validGreen)
                Text("Resultado").font(.headline)
                Spacer()
                Button(action: { UIPasteboard.general.string = casResult.output.pretty }) {
                    Image(systemName: "doc.on.doc").font(.subheadline)
                }.foregroundColor(.secondary)
                Button(action: { showGraph.toggle() }) {
                    Image(systemName: "chart.xyaxis.line").font(.subheadline)
                        .foregroundColor(showGraph ? MathDFColors.accent : .secondary)
                }
            }
            MathText(latex: casResult.latex, fontSize: 22).frame(maxWidth: .infinity, minHeight: 50)
            Text(casResult.output.pretty).font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MathDFColors.validGreen.opacity(0.3), lineWidth: 1)))
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
        let ptCorrected = SmartCorrector.correct(pointText).corrected
        
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = CASEngine.shared
            // Build limit expression: limit(expr, var, point)
            let limitExpr = "limit(\(corrected), \(variable), \(ptCorrected))"
            let casResult = engine.process(limitExpr)
            let steps = SolutionStepData.fromEngineSteps(casResult.steps)
            
            var gFuncs: [GraphFunction] = []
            let inputNode = casResult.input
            gFuncs.append(GraphFunction(label: "f(\(variable))", color: MathModule.limit.accentColor,
                evaluate: { x, _ in inputNode.evaluate(with: [variable: x]) ?? 0 }))
            
            DispatchQueue.main.async {
                self.result = casResult; self.stepData = steps
                self.graphFunctions = gFuncs; self.showGraph = true; self.isComputing = false
                appState.addToHistory(HistoryItem(module: .limit, input: "\(inputText), \(variable)→\(pointText)",
                    resultLatex: casResult.latex, resultPlain: casResult.output.pretty))
            }
        }
    }
    
    private let limitExamples: [(String, String, String)] = [
        ("sin(x)/x", "sin(x)/x", "0"),
        ("(1+1/x)^x", "(1+1/x)^x", "inf"),
        ("(e^x-1)/x", "(e^x-1)/x", "0"),
        ("x*ln(x)", "x*ln(x)", "0+"),
        ("(x^2-1)/(x-1)", "(x^2-1)/(x-1)", "1"),
    ]
}

#Preview {
    NavigationStack { LimitView().environmentObject(AppState()) }
}
