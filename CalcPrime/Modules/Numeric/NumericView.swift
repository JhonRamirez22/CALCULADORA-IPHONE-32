// NumericView.swift
// CalcPrime — MathDF iOS
// Numeric evaluation module — precision control, constants, conversions.

import SwiftUI

struct NumericView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText = ""
    @State private var precision = 10
    @State private var angleUnit: AngleUnit = .radians
    @State private var result: CASResult?
    @State private var numericResult: String?
    @State private var stepData: [SolutionStepData] = []
    @State private var isComputing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                inputSection
                optionsSection
                solveButton
                
                if let numRes = numericResult { numericResultSection(numRes) }
                if let error = errorMessage { errorBanner(error) }
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.numeric.accentColor)
                }
                
                // Quick constants
                constantsSection
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Numérico")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                MathKeyboardStrip(text: $inputText, module: .numeric)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expresión a evaluar")
                .font(.subheadline.bold()).foregroundColor(.secondary)
            
            SmartInputField(
                placeholder: "Ej: sqrt(2), pi^e, sin(pi/4)",
                text: $inputText,
                onSubmit: solve
            )
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Precisión:").font(.subheadline).foregroundColor(.secondary)
                Text("\(precision) decimales").font(.subheadline.bold())
                Spacer()
                Stepper("", value: $precision, in: 1...30)
                    .frame(width: 100)
            }
            
            HStack {
                Text("Ángulos:").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $angleUnit) {
                    Text("Radianes").tag(AngleUnit.radians)
                    Text("Grados").tag(AngleUnit.degrees)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
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
                    Image(systemName: "number")
                    Text("EVALUAR").fontWeight(.bold)
                }
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(inputText.isEmpty ? Color.gray : MathModule.numeric.accentColor))
        }
        .disabled(inputText.isEmpty || isComputing)
    }
    
    private func numericResultSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundColor(MathDFColors.validGreen)
                Text("Valor numérico").font(.headline)
                Spacer()
                Button(action: { UIPasteboard.general.string = text }) {
                    Image(systemName: "doc.on.doc").font(.subheadline)
                }.foregroundColor(.secondary)
            }
            
            Text(text)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            
            if let result = result {
                MathText(latex: result.latex, fontSize: 18).frame(maxWidth: .infinity, minHeight: 40)
            }
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
    
    private var constantsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Constantes útiles").font(.subheadline.bold()).foregroundColor(.secondary)
            
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(constants, id: \.0) { name, value, symbol in
                    Button(action: { inputText = symbol }) {
                        HStack {
                            Text(name).font(.caption.bold()).foregroundColor(.primary)
                            Spacer()
                            Text(value).font(.caption2.monospaced()).foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
    }
    
    // MARK: - Solve
    
    private func solve() {
        guard !inputText.isEmpty else { return }
        isComputing = true; errorMessage = nil; numericResult = nil; result = nil; stepData = []
        
        let corrected = SmartCorrector.correct(inputText).corrected
        
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = CASEngine.shared
            let casResult = engine.evaluate(corrected)
            let steps = SolutionStepData.fromEngineSteps(casResult.steps)
            
            // Get numeric value
            var numStr: String
            if let val = casResult.output.evaluate(with: [:]) {
                numStr = String(format: "%.\(precision)g", val)
            } else {
                numStr = casResult.output.pretty
            }
            
            DispatchQueue.main.async {
                self.result = casResult; self.numericResult = numStr
                self.stepData = steps; self.isComputing = false
                appState.addToHistory(HistoryItem(module: .numeric, input: inputText,
                    resultLatex: casResult.latex, resultPlain: numStr))
            }
        }
    }
    
    private let constants: [(String, String, String)] = [
        ("π", "3.14159265...", "pi"),
        ("e", "2.71828182...", "e"),
        ("φ (áureo)", "1.61803398...", "(1+sqrt(5))/2"),
        ("√2", "1.41421356...", "sqrt(2)"),
        ("ln(2)", "0.69314718...", "ln(2)"),
        ("γ (Euler)", "0.57721566...", "0.5772156649"),
    ]
}

#Preview {
    NavigationStack { NumericView().environmentObject(AppState()) }
}
