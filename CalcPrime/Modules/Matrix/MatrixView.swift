// MatrixView.swift
// CalcPrime — MathDF iOS
// Matrices module — operations, determinant, inverse, Gauss elimination.

import SwiftUI

struct MatrixView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var rows = 3
    @State private var cols = 3
    @State private var matrixValues: [[String]] = Array(repeating: Array(repeating: "", count: 3), count: 3)
    @State private var operation: MatrixOperation = .determinant
    @State private var result: CASResult?
    @State private var stepData: [SolutionStepData] = []
    @State private var isComputing = false
    @State private var errorMessage: String?
    @State private var resultText: String?
    
    enum MatrixOperation: String, CaseIterable {
        case determinant = "Determinante"
        case inverse = "Inversa"
        case rref = "Gauss-Jordan"
        case eigenvalues = "Autovalores"
        case transpose = "Transpuesta"
        case rank = "Rango"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dimensionPicker
                matrixGrid
                operationPicker
                solveButton
                
                if let text = resultText { resultSection(text) }
                if let error = errorMessage { errorBanner(error) }
                if !stepData.isEmpty {
                    StepByStepView(steps: stepData, accentColor: MathModule.matrix.accentColor)
                }
                
                Spacer(minLength: 60)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Matrices")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Dimension Picker
    
    private var dimensionPicker: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Filas").font(.caption).foregroundColor(.secondary)
                Stepper("\(rows)", value: $rows, in: 1...6)
                    .frame(width: 120)
            }
            VStack(spacing: 4) {
                Text("Columnas").font(.caption).foregroundColor(.secondary)
                Stepper("\(cols)", value: $cols, in: 1...6)
                    .frame(width: 120)
            }
            
            Spacer()
            
            Button("Limpiar") {
                matrixValues = Array(repeating: Array(repeating: "", count: cols), count: rows)
            }
            .font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
        .onChange(of: rows) { _, newRows in resizeMatrix(newRows: newRows, newCols: cols) }
        .onChange(of: cols) { _, newCols in resizeMatrix(newRows: rows, newCols: newCols) }
    }
    
    // MARK: - Matrix Grid Input
    
    private var matrixGrid: some View {
        VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 2) {
                    if r == rows / 2 {
                        Text("[").font(.system(size: 40, weight: .ultraLight))
                    } else {
                        Text(" ").font(.system(size: 40))
                    }
                    
                    ForEach(0..<cols, id: \.self) { c in
                        TextField("0", text: matrixBinding(row: r, col: c))
                            .font(.system(size: 16, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .frame(minWidth: 44, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray6))
                            )
                            .keyboardType(.numbersAndPunctuation)
                    }
                    
                    if r == rows / 2 {
                        Text("]").font(.system(size: 40, weight: .ultraLight))
                    } else {
                        Text(" ").font(.system(size: 40))
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
    }
    
    // MARK: - Operation Picker
    
    private var operationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operación").font(.subheadline.bold()).foregroundColor(.secondary)
            
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(MatrixOperation.allCases, id: \.self) { op in
                    Button(action: { operation = op }) {
                        Text(op.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(operation == op ? .white : MathModule.matrix.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(operation == op ? MathModule.matrix.accentColor : MathModule.matrix.accentColor.opacity(0.1))
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
                    Image(systemName: "square.grid.3x3")
                    Text("CALCULAR").fontWeight(.bold)
                }
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(MathModule.matrix.accentColor))
        }
        .disabled(isComputing)
    }
    
    private func resultSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundColor(MathDFColors.validGreen)
                Text("Resultado").font(.headline)
                Spacer()
                Button(action: { UIPasteboard.general.string = text }) {
                    Image(systemName: "doc.on.doc").font(.subheadline)
                }.foregroundColor(.secondary)
            }
            
            Text(text)
                .font(.system(size: 16, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Helpers
    
    private func matrixBinding(row: Int, col: Int) -> Binding<String> {
        Binding(
            get: {
                guard row < matrixValues.count, col < matrixValues[row].count else { return "" }
                return matrixValues[row][col]
            },
            set: { newValue in
                guard row < matrixValues.count, col < matrixValues[row].count else { return }
                matrixValues[row][col] = newValue
            }
        )
    }
    
    private func resizeMatrix(newRows: Int, newCols: Int) {
        var newMatrix: [[String]] = []
        for r in 0..<newRows {
            var row: [String] = []
            for c in 0..<newCols {
                if r < matrixValues.count && c < matrixValues[r].count {
                    row.append(matrixValues[r][c])
                } else {
                    row.append("")
                }
            }
            newMatrix.append(row)
        }
        matrixValues = newMatrix
    }
    
    // MARK: - Solve
    
    private func solve() {
        isComputing = true; errorMessage = nil; resultText = nil; stepData = []
        
        // Build matrix string: [[1,2,3],[4,5,6],[7,8,9]]
        let matStr = "[" + matrixValues.prefix(rows).map { row in
            "[" + row.prefix(cols).map { $0.isEmpty ? "0" : $0 }.joined(separator: ",") + "]"
        }.joined(separator: ",") + "]"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = CASEngine.shared
            let expr: String
            
            switch operation {
            case .determinant: expr = "det(\(matStr))"
            case .inverse: expr = "inverse(\(matStr))"
            case .rref: expr = "rref(\(matStr))"
            case .eigenvalues: expr = "eigenvalues(\(matStr))"
            case .transpose: expr = "transpose(\(matStr))"
            case .rank: expr = "rank(\(matStr))"
            }
            
            let casResult = engine.process(expr)
            let steps = SolutionStepData.fromEngineSteps(casResult.steps)
            
            DispatchQueue.main.async {
                self.resultText = casResult.output.pretty
                self.stepData = steps
                self.isComputing = false
                
                appState.addToHistory(HistoryItem(module: .matrix, input: "\(operation.rawValue) \(rows)×\(cols)",
                    resultLatex: casResult.latex, resultPlain: casResult.output.pretty))
            }
        }
    }
}

#Preview {
    NavigationStack { MatrixView().environmentObject(AppState()) }
}
