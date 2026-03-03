// KeypadView.swift
// CalcPrime — Views
// 4-layer swipeable keypad with HP Prime-inspired button grid.
// Layers: Basic, Scientific, Calculus, Advanced.

import SwiftUI

struct KeypadView: View {
    @ObservedObject var appState: AppState
    
    var theme: AppTheme { appState.preferences.theme }
    
    var body: some View {
        TabView(selection: $appState.currentLayer) {
            ForEach(KeypadLayer.allCases, id: \.rawValue) { layer in
                keypadGrid(for: layer)
                    .tag(layer)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(theme.bodyColor)
    }
    
    // MARK: - Grid for Layer
    
    @ViewBuilder
    private func keypadGrid(for layer: KeypadLayer) -> some View {
        let buttons = buttonsForLayer(layer)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(buttons, id: \.label) { btn in
                    CalcButton(
                        label: btn.label,
                        secondLabel: btn.secondLabel,
                        color: btn.color,
                        textColor: btn.textColor,
                        fontSize: btn.fontSize,
                        action: { handleButton(btn) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Button Handling
    
    private func handleButton(_ btn: ButtonConfig) {
        if appState.preferences.hapticFeedback {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        switch btn.action {
        case .input(let text):
            appState.appendInput(text)
        case .evaluate:
            appState.evaluate()
        case .delete:
            appState.deleteLastCharacter()
        case .clear:
            appState.clearInput()
        case .allClear:
            appState.clearAll()
        case .shift:
            appState.toggleShift()
        case .alpha:
            appState.toggleAlpha()
        }
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Button Configurations per Layer
    // ═══════════════════════════════════════════
    
    private func buttonsForLayer(_ layer: KeypadLayer) -> [ButtonConfig] {
        switch layer {
        case .basic: return basicButtons
        case .scientific: return scientificButtons
        case .calculus: return calculusButtons
        case .advanced: return advancedButtons
        }
    }
    
    // ── Layer 0: Basic ──
    private var basicButtons: [ButtonConfig] {
        let t = theme
        return [
            // Row 1
            .init(label: "SHIFT", color: t.buttonAccent, action: .shift),
            .init(label: "ALPHA", color: t.buttonSecondary, action: .alpha),
            .init(label: "(", secondLabel: "[", color: t.buttonPrimary, action: .input("(")),
            .init(label: ")", secondLabel: "]", color: t.buttonPrimary, action: .input(")")),
            .init(label: "⌫", color: Color.red.opacity(0.7), action: .delete),
            // Row 2
            .init(label: "7", color: t.buttonPrimary, fontSize: 22, action: .input("7")),
            .init(label: "8", color: t.buttonPrimary, fontSize: 22, action: .input("8")),
            .init(label: "9", color: t.buttonPrimary, fontSize: 22, action: .input("9")),
            .init(label: "÷", color: t.buttonSecondary, fontSize: 22, action: .input("/")),
            .init(label: "AC", color: Color.red.opacity(0.7), action: .allClear),
            // Row 3
            .init(label: "4", color: t.buttonPrimary, fontSize: 22, action: .input("4")),
            .init(label: "5", color: t.buttonPrimary, fontSize: 22, action: .input("5")),
            .init(label: "6", color: t.buttonPrimary, fontSize: 22, action: .input("6")),
            .init(label: "×", color: t.buttonSecondary, fontSize: 22, action: .input("*")),
            .init(label: "C", color: Color.red.opacity(0.5), action: .clear),
            // Row 4
            .init(label: "1", color: t.buttonPrimary, fontSize: 22, action: .input("1")),
            .init(label: "2", color: t.buttonPrimary, fontSize: 22, action: .input("2")),
            .init(label: "3", color: t.buttonPrimary, fontSize: 22, action: .input("3")),
            .init(label: "−", color: t.buttonSecondary, fontSize: 22, action: .input("-")),
            .init(label: "^", secondLabel: "√", color: t.buttonPrimary, action: .input("^")),
            // Row 5
            .init(label: "0", color: t.buttonPrimary, fontSize: 22, action: .input("0")),
            .init(label: ".", color: t.buttonPrimary, fontSize: 22, action: .input(".")),
            .init(label: "EXP", color: t.buttonPrimary, fontSize: 12, action: .input("E")),
            .init(label: "+", color: t.buttonSecondary, fontSize: 22, action: .input("+")),
            .init(label: "=", color: t.buttonAccent, fontSize: 22, action: .evaluate),
        ]
    }
    
    // ── Layer 1: Scientific ──
    private var scientificButtons: [ButtonConfig] {
        let t = theme
        return [
            .init(label: "sin", color: t.buttonPrimary, action: .input("sin(")),
            .init(label: "cos", color: t.buttonPrimary, action: .input("cos(")),
            .init(label: "tan", color: t.buttonPrimary, action: .input("tan(")),
            .init(label: "π", color: t.buttonSecondary, action: .input("π")),
            .init(label: "e", color: t.buttonSecondary, action: .input("e")),
            
            .init(label: "asin", color: t.buttonPrimary, fontSize: 12, action: .input("asin(")),
            .init(label: "acos", color: t.buttonPrimary, fontSize: 12, action: .input("acos(")),
            .init(label: "atan", color: t.buttonPrimary, fontSize: 12, action: .input("atan(")),
            .init(label: "ln", color: t.buttonPrimary, action: .input("ln(")),
            .init(label: "log", color: t.buttonPrimary, action: .input("log(")),
            
            .init(label: "sinh", color: t.buttonPrimary, fontSize: 12, action: .input("sinh(")),
            .init(label: "cosh", color: t.buttonPrimary, fontSize: 12, action: .input("cosh(")),
            .init(label: "tanh", color: t.buttonPrimary, fontSize: 12, action: .input("tanh(")),
            .init(label: "eˣ", color: t.buttonPrimary, action: .input("exp(")),
            .init(label: "10ˣ", color: t.buttonPrimary, fontSize: 12, action: .input("10^")),
            
            .init(label: "x²", color: t.buttonPrimary, action: .input("^2")),
            .init(label: "√", color: t.buttonPrimary, action: .input("sqrt(")),
            .init(label: "∛", color: t.buttonPrimary, action: .input("cbrt(")),
            .init(label: "|x|", color: t.buttonPrimary, action: .input("abs(")),
            .init(label: "n!", color: t.buttonPrimary, action: .input("!")),
            
            .init(label: "x", color: t.buttonSecondary, action: .input("x")),
            .init(label: "y", color: t.buttonSecondary, action: .input("y")),
            .init(label: ",", color: t.buttonPrimary, action: .input(",")),
            .init(label: "Ans", color: t.buttonAccent, fontSize: 12, action: .input("Ans")),
            .init(label: "=", color: t.buttonAccent, fontSize: 22, action: .evaluate),
        ]
    }
    
    // ── Layer 2: Calculus ──
    private var calculusButtons: [ButtonConfig] {
        let t = theme
        return [
            .init(label: "d/dx", color: t.buttonSecondary, fontSize: 12, action: .input("d/dx ")),
            .init(label: "∫", color: t.buttonSecondary, fontSize: 20, action: .input("∫")),
            .init(label: "∫ab", color: t.buttonSecondary, fontSize: 12, action: .input("∫(")),
            .init(label: "lim", color: t.buttonSecondary, fontSize: 12, action: .input("lim ")),
            .init(label: "Σ", color: t.buttonSecondary, fontSize: 18, action: .input("Σ(")),
            
            .init(label: "d²/dx²", color: t.buttonPrimary, fontSize: 10, action: .input("d²/dx² ")),
            .init(label: "∂/∂x", color: t.buttonPrimary, fontSize: 12, action: .input("∂/∂x ")),
            .init(label: "∇", color: t.buttonPrimary, action: .input("∇")),
            .init(label: "∞", color: t.buttonPrimary, action: .input("∞")),
            .init(label: "Π", color: t.buttonPrimary, fontSize: 18, action: .input("Π(")),
            
            .init(label: "solve", color: t.buttonAccent, fontSize: 11, action: .input("solve(")),
            .init(label: "factor", color: t.buttonAccent, fontSize: 11, action: .input("factor(")),
            .init(label: "expand", color: t.buttonPrimary, fontSize: 11, action: .input("expand(")),
            .init(label: "simplify", color: t.buttonPrimary, fontSize: 10, action: .input("simplify(")),
            .init(label: "collect", color: t.buttonPrimary, fontSize: 10, action: .input("collect(")),
            
            .init(label: "Taylor", color: t.buttonPrimary, fontSize: 11, action: .input("taylor(")),
            .init(label: "Laplace", color: t.buttonPrimary, fontSize: 10, action: .input("laplace(")),
            .init(label: "Fourier", color: t.buttonPrimary, fontSize: 10, action: .input("fourier(")),
            .init(label: "ODE", color: t.buttonPrimary, fontSize: 12, action: .input("ode(")),
            .init(label: "PDE", color: t.buttonPrimary, fontSize: 12, action: .input("pde(")),
            
            .init(label: "x", color: t.buttonSecondary, action: .input("x")),
            .init(label: "y", color: t.buttonSecondary, action: .input("y")),
            .init(label: "t", color: t.buttonSecondary, action: .input("t")),
            .init(label: "=", color: t.buttonPrimary, action: .input("=")),
            .init(label: "⏎", color: t.buttonAccent, fontSize: 22, action: .evaluate),
        ]
    }
    
    // ── Layer 3: Advanced ──
    private var advancedButtons: [ButtonConfig] {
        let t = theme
        return [
            .init(label: "matrix", color: t.buttonSecondary, fontSize: 10, action: .input("[[")),
            .init(label: "det", color: t.buttonPrimary, fontSize: 12, action: .input("det(")),
            .init(label: "inv", color: t.buttonPrimary, fontSize: 12, action: .input("inverse(")),
            .init(label: "eigen", color: t.buttonPrimary, fontSize: 10, action: .input("eigenvalues(")),
            .init(label: "rref", color: t.buttonPrimary, fontSize: 12, action: .input("rref(")),
            
            .init(label: "Γ", color: t.buttonPrimary, action: .input("gamma(")),
            .init(label: "β", color: t.buttonPrimary, action: .input("beta(")),
            .init(label: "ζ", color: t.buttonPrimary, action: .input("zeta(")),
            .init(label: "erf", color: t.buttonPrimary, fontSize: 12, action: .input("erf(")),
            .init(label: "W", color: t.buttonPrimary, action: .input("lambertW(")),
            
            .init(label: "Jₙ", color: t.buttonPrimary, action: .input("besselJ(")),
            .init(label: "Yₙ", color: t.buttonPrimary, action: .input("besselY(")),
            .init(label: "Ai", color: t.buttonPrimary, action: .input("airyAi(")),
            .init(label: "Pₙ", color: t.buttonPrimary, action: .input("legendreP(")),
            .init(label: "Hₙ", color: t.buttonPrimary, action: .input("hermiteH(")),
            
            .init(label: "nCr", color: t.buttonPrimary, fontSize: 12, action: .input("binomial(")),
            .init(label: "nPr", color: t.buttonPrimary, fontSize: 12, action: .input("permutation(")),
            .init(label: "gcd", color: t.buttonPrimary, fontSize: 12, action: .input("gcd(")),
            .init(label: "lcm", color: t.buttonPrimary, fontSize: 12, action: .input("lcm(")),
            .init(label: "mod", color: t.buttonPrimary, fontSize: 12, action: .input("mod(")),
            
            .init(label: "Re", color: t.buttonPrimary, action: .input("real(")),
            .init(label: "Im", color: t.buttonPrimary, action: .input("imag(")),
            .init(label: "i", color: t.buttonSecondary, action: .input("i")),
            .init(label: "∠", color: t.buttonPrimary, action: .input("arg(")),
            .init(label: "⏎", color: t.buttonAccent, fontSize: 22, action: .evaluate),
        ]
    }
}

// MARK: - Button Config

struct ButtonConfig {
    let label: String
    var secondLabel: String? = nil
    let color: Color
    var textColor: Color = .white
    var fontSize: CGFloat = 16
    let action: ButtonAction
}

enum ButtonAction {
    case input(String)
    case evaluate
    case delete
    case clear
    case allClear
    case shift
    case alpha
}

// MARK: - CalcButton

struct CalcButton: View {
    let label: String
    var secondLabel: String? = nil
    let color: Color
    var textColor: Color = .white
    var fontSize: CGFloat = 16
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                if let sec = secondLabel {
                    Text(sec)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.orange.opacity(0.7))
                }
                Text(label)
                    .font(.system(size: fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .shadow(color: .black.opacity(0.3), radius: isPressed ? 0 : 2, x: 0, y: isPressed ? 0 : 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.05)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.1)) { isPressed = false } }
        )
    }
}
