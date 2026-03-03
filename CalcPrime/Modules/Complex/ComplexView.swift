// ComplexView.swift
// CalcPrime — MathDF iOS
// Complex numbers — arithmetic, polar form, De Moivre, nth roots, Argand diagram.

import SwiftUI

struct ComplexView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText = ""
    @State private var operation: ComplexOp = .simplify
    @State private var result: CASResult?
    @State private var stepData: [SolutionStepData] = []
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var showGraph = false
    @State private var graphFunctions: [GraphFunction] = []
    
    enum ComplexOp: String, CaseIterable {
        case simplify = "Simplificar"
        case polar = "Forma polar"
        case conjugate = "Conjugado"
        case modulus = "Módulo"
        case argument = "Argumento"
        case roots = "Raíces n-ésimas"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                inputSection
                operationPicker
                solveButton
                
                if let result = result { resultSection(result) }
                if let error = errorMessage { errorBanner(error) }
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.complex.accentColor)
                }
                
                // Argand diagram placeholder
                if showGraph {
                    argandSection
                }
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Números Complejos")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                MathKeyboardStrip(text: $inputText, module: .complex)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expresión compleja")
                .font(.subheadline.bold()).foregroundColor(.secondary)
            
            SmartInputField(
                placeholder: "Ej: (3+4i)*(1-2i), e^(i*pi), (1+i)^5",
                text: $inputText,
                onSubmit: solve
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(complexExamples, id: \.0) { name, expr in
                        Button(action: { inputText = expr }) {
                            Text(name).font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(MathModule.complex.accentColor.opacity(0.1)))
                                .foregroundColor(MathModule.complex.accentColor)
                        }
                    }
                }
            }
        }
    }
    
    private var operationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operación").font(.subheadline.bold()).foregroundColor(.secondary)
            
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(ComplexOp.allCases, id: \.self) { op in
                    Button(action: { operation = op }) {
                        Text(op.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(operation == op ? .white : MathModule.complex.accentColor)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(operation == op ? MathModule.complex.accentColor : MathModule.complex.accentColor.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
    }
    
    private var solveButton: some View {
        Button(action: solve) {
            HStack(spacing: 8) {
                if isComputing { ProgressView().tint(.white) }
                else {
                    Image(systemName: "sum")
                    Text("CALCULAR").fontWeight(.bold)
                }
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(inputText.isEmpty ? Color.gray : MathModule.complex.accentColor))
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
    
    private var argandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagrama de Argand").font(.headline)
            
            // Simple Argand diagram using GraphView
            GraphView(
                functions: [
                    GraphFunction(label: "Re", color: .gray,
                        evaluate: { _, _ in 0 }, isDashed: true)
                ],
                showSlider: false
            )
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Solve
    
    private func solve() {
        guard !inputText.isEmpty else { return }
        isComputing = true; errorMessage = nil; result = nil; stepData = []
        
        let corrected = SmartCorrector.correct(inputText).corrected
        
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = CASEngine.shared
            let expr: String
            
            switch operation {
            case .simplify: expr = corrected
            case .polar: expr = "polar(\(corrected))"
            case .conjugate: expr = "conjugate(\(corrected))"
            case .modulus: expr = "abs(\(corrected))"
            case .argument: expr = "arg(\(corrected))"
            case .roots: expr = "roots(\(corrected))"
            }
            
            let casResult = engine.process(expr)
            let steps = SolutionStepData.fromEngineSteps(casResult.steps)
            
            DispatchQueue.main.async {
                self.result = casResult; self.stepData = steps
                self.showGraph = true; self.isComputing = false
                appState.addToHistory(HistoryItem(module: .complex, input: inputText,
                    resultLatex: casResult.latex, resultPlain: casResult.output.pretty))
            }
        }
    }
    
    private let complexExamples: [(String, String)] = [
        ("(3+4i)²", "(3+4i)^2"),
        ("e^(iπ)", "e^(i*pi)"),
        ("|2+3i|", "abs(2+3i)"),
        ("(1+i)^8", "(1+i)^8"),
        ("√(-4)", "sqrt(-4)"),
    ]
}

#Preview {
    NavigationStack { ComplexView().environmentObject(AppState()) }
}
