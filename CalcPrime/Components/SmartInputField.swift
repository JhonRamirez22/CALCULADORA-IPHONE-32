// SmartInputField.swift
// CalcPrime — MathDF iOS
// Text field with real-time LaTeX preview and smart correction.

import SwiftUI

struct SmartInputField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil
    
    @State private var correctionResult: CorrectionResult = CorrectionResult(corrected: "", latex: "", isValid: false, message: nil)
    @State private var showPreview: Bool = true
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Input Field
            HStack(spacing: 10) {
                Image(systemName: "function")
                    .foregroundColor(fieldAccent)
                    .font(.system(size: 16, weight: .medium))
                
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .font(.system(size: 18, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit {
                        onSubmit?()
                    }
                
                // Validation indicator
                if !text.isEmpty {
                    validationIcon
                }
                
                // Clear button
                if !text.isEmpty {
                    Button(action: { text = ""; correctionResult = CorrectionResult(corrected: "", latex: "", isValid: false, message: nil) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(fieldBorder, lineWidth: isFocused ? 2 : 1)
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            
            // LaTeX Preview
            if showPreview && !text.isEmpty && correctionResult.isValid {
                MathPreview(latex: correctionResult.latex, isValid: true)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // Error message
            if !text.isEmpty && !correctionResult.isValid && correctionResult.message != nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(correctionResult.message ?? "")
                        .font(.caption)
                }
                .foregroundColor(MathDFColors.errorRed)
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
            
            // Corrected text (if different from input)
            if correctionResult.isValid && correctionResult.corrected != text && !correctionResult.corrected.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                    Text("Corregido: \(correctionResult.corrected)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Aplicar") {
                        text = correctionResult.corrected
                    }
                    .font(.caption.bold())
                    .foregroundColor(MathDFColors.accent)
                }
                .padding(.horizontal, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: correctionResult.isValid)
        .animation(.easeInOut(duration: 0.2), value: text)
        .onChange(of: text) { _, newValue in
            updateCorrection(for: newValue)
        }
    }
    
    // MARK: - Validation Icon
    
    @ViewBuilder
    private var validationIcon: some View {
        if correctionResult.isValid {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(MathDFColors.validGreen)
                .transition(.scale.combined(with: .opacity))
        } else {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(MathDFColors.errorRed)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var fieldAccent: Color {
        if text.isEmpty { return .secondary }
        return correctionResult.isValid ? MathDFColors.accent : MathDFColors.errorRed
    }
    
    private var fieldBorder: Color {
        if !isFocused { return Color(.systemGray4) }
        if text.isEmpty { return MathDFColors.accent }
        return correctionResult.isValid ? MathDFColors.accent : MathDFColors.errorRed
    }
    
    // MARK: - Correction Logic
    
    private func updateCorrection(for input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            correctionResult = CorrectionResult(corrected: "", latex: "", isValid: false, message: nil)
            return
        }
        correctionResult = SmartCorrector.correct(trimmed)
    }
}

// MARK: - Multi-field Smart Input (for systems, ODEs, etc.)

struct SmartInputFieldMulti: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            SmartInputField(placeholder: placeholder, text: $text)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SmartInputField(
            placeholder: "Ej: 2sinx + e^(2x)",
            text: .constant("2sinx + e^(2x)")
        )
        
        SmartInputFieldMulti(
            label: "Ecuación diferencial",
            placeholder: "y' + 2y = sin(x)",
            text: .constant("y' + 2y = sin(x)")
        )
    }
    .padding()
}
