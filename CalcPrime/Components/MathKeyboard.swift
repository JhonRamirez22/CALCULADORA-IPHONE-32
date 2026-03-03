// MathKeyboard.swift
// CalcPrime — MathDF iOS
// Custom accessory keyboard strip with math symbols.

import SwiftUI

struct MathKeyboardStrip: View {
    @Binding var text: String
    var module: MathModule = .integral
    
    private let commonSymbols: [(String, String)] = [
        ("x", "x"), ("y", "y"), ("(", "("), (")", ")"),
        ("^", "^"), ("/", "/"), ("√", "sqrt("),
        ("π", "pi"), ("e", "e"), ("∞", "inf"),
    ]
    
    private let operatorSymbols: [(String, String)] = [
        ("+", "+"), ("−", "-"), ("×", "*"), ("÷", "/"),
        ("=", "="), ("<", "<"), (">", ">"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Module-specific buttons first
                    ForEach(moduleSpecificButtons, id: \.0) { label, insertion in
                        keyButton(label: label) {
                            text += insertion
                        }
                    }
                    
                    Divider()
                        .frame(height: 28)
                    
                    // Common symbols
                    ForEach(commonSymbols, id: \.0) { label, insertion in
                        keyButton(label: label) {
                            text += insertion
                        }
                    }
                    
                    Divider()
                        .frame(height: 28)
                    
                    // Operators
                    ForEach(operatorSymbols, id: \.0) { label, insertion in
                        keyButton(label: label) {
                            text += insertion
                        }
                    }
                    
                    Divider()
                        .frame(height: 28)
                    
                    // Functions
                    ForEach(functionButtons, id: \.0) { label, insertion in
                        keyButton(label: label, isWide: true) {
                            text += insertion
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 44)
            .background(Color(.systemGray6))
        }
    }
    
    // MARK: - Key Button
    
    private func keyButton(label: String, isWide: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(isWide ? .system(size: 13, weight: .medium) : .system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(minWidth: isWide ? 44 : 32, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                )
        }
    }
    
    // MARK: - Module-Specific Buttons
    
    private var moduleSpecificButtons: [(String, String)] {
        switch module {
        case .integral:
            return [("∫", "∫"), ("dx", "dx"), ("dy", "dy"), ("|a,b|", "[,]")]
        case .ode:
            return [("y'", "y'"), ("y''", "y''"), ("y(0)", "y(0)=")]
        case .derivative:
            return [("d/dx", "d/dx"), ("∂", "∂"), ("'", "'")]
        case .equation:
            return [("=0", "=0"), ("x²", "x^2"), ("x³", "x^3")]
        case .limit:
            return [("→", "->"), ("0⁺", "0+"), ("0⁻", "0-"), ("∞", "inf")]
        case .matrix:
            return [("[", "["), ("]", "]"), (",", ","), (";", ";")]
        case .complex:
            return [("i", "i"), ("|z|", "abs("), ("arg", "arg("), ("°", "*pi/180")]
        case .numeric:
            return [(".", "."), ("E", "E"), ("ans", "ans")]
        }
    }
    
    private var functionButtons: [(String, String)] {
        [
            ("sin", "sin("), ("cos", "cos("), ("tan", "tan("),
            ("ln", "ln("), ("log", "log("), ("exp", "exp("),
            ("abs", "abs("),
        ]
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        MathKeyboardStrip(text: .constant(""), module: .integral)
    }
}
