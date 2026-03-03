// CalculationResult.swift
// CalcPrime — Models
// Data models for calculation results, history, and user preferences.

import Foundation
import SwiftUI

// MARK: - CalculationResult

struct CalculationResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let input: String
    let output: String
    let latex: String
    let steps: [SolutionStepData]
    let category: CalculationCategory
    let timeElapsed: Double  // seconds
    
    init(id: UUID = UUID(), timestamp: Date = Date(), input: String, output: String,
         latex: String, steps: [SolutionStepData] = [], category: CalculationCategory = .general,
         timeElapsed: Double = 0) {
        self.id = id
        self.timestamp = timestamp
        self.input = input
        self.output = output
        self.latex = latex
        self.steps = steps
        self.category = category
        self.timeElapsed = timeElapsed
    }
    
    /// Create from CASResult.
    static func from(_ casResult: CASResult, category: CalculationCategory = .general) -> CalculationResult {
        CalculationResult(
            input: casResult.input.pretty,
            output: casResult.output.pretty,
            latex: casResult.latex,
            steps: casResult.steps.map { SolutionStepData.from($0) },
            category: category,
            timeElapsed: casResult.timeElapsed
        )
    }
}

// MARK: - SolutionStepData (Codable version)

struct SolutionStepData: Identifiable, Codable {
    let id: UUID
    let title: String
    let explanation: String
    let math: String
    let substeps: [SolutionStepData]
    
    static func from(_ step: SolutionStep) -> SolutionStepData {
        SolutionStepData(
            id: step.id,
            title: step.title,
            explanation: step.explanation,
            math: step.math,
            substeps: step.substeps.map { from($0) }
        )
    }
}

// MARK: - CalculationCategory

enum CalculationCategory: String, Codable, CaseIterable {
    case general        = "General"
    case derivative     = "Derivadas"
    case integral       = "Integrales"
    case equation       = "Ecuaciones"
    case factorization  = "Factorización"
    case ode            = "EDOs"
    case pde            = "EDPs"
    case linearAlgebra  = "Álgebra Lineal"
    case series         = "Series"
    case transform      = "Transformadas"
    case numerical      = "Métodos Numéricos"
    case graph          = "Gráficas"
    
    var icon: String {
        switch self {
        case .general: return "function"
        case .derivative: return "arrow.up.right"
        case .integral: return "sum"
        case .equation: return "equal"
        case .factorization: return "square.grid.2x2"
        case .ode: return "waveform.path.ecg"
        case .pde: return "square.3.layers.3d"
        case .linearAlgebra: return "square.grid.3x3"
        case .series: return "ellipsis"
        case .transform: return "arrow.left.arrow.right"
        case .numerical: return "number"
        case .graph: return "chart.xyaxis.line"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .white
        case .derivative: return .orange
        case .integral: return .blue
        case .equation: return .green
        case .factorization: return .purple
        case .ode: return .red
        case .pde: return .pink
        case .linearAlgebra: return .cyan
        case .series: return .yellow
        case .transform: return .mint
        case .numerical: return .teal
        case .graph: return .indigo
        }
    }
}

// MARK: - HistoryEntry

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let input: String
    let output: String
    let latex: String
    let category: CalculationCategory
    let isFavorite: Bool
    
    init(id: UUID = UUID(), timestamp: Date = Date(), input: String,
         output: String, latex: String, category: CalculationCategory = .general,
         isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.input = input
        self.output = output
        self.latex = latex
        self.category = category
        self.isFavorite = isFavorite
    }
    
    static func from(_ result: CalculationResult) -> HistoryEntry {
        HistoryEntry(
            input: result.input,
            output: result.output,
            latex: result.latex,
            category: result.category
        )
    }
    
    func toggleFavorite() -> HistoryEntry {
        HistoryEntry(id: id, timestamp: timestamp, input: input,
                     output: output, latex: latex, category: category,
                     isFavorite: !isFavorite)
    }
}

// MARK: - UserPreferences

struct UserPreferences: Codable {
    var theme: AppTheme
    var angleUnit: AngleUnit
    var precision: Int            // Decimal places
    var showSteps: Bool
    var autoSimplify: Bool
    var hapticFeedback: Bool
    var soundEffects: Bool
    var fontSize: FontSizeOption
    var historyLimit: Int
    var defaultVariable: String
    
    static let `default` = UserPreferences(
        theme: .dark,
        angleUnit: .radians,
        precision: 10,
        showSteps: true,
        autoSimplify: true,
        hapticFeedback: true,
        soundEffects: false,
        fontSize: .medium,
        historyLimit: 500,
        defaultVariable: "x"
    )
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case dark       = "Oscuro (HP Prime)"
    case midnight   = "Medianoche"
    case light      = "Claro"
    
    var id: String { rawValue }
    
    var displayBackground: Color {
        switch self {
        case .dark: return Color(hex: "0A0A0F")
        case .midnight: return Color(hex: "050510")
        case .light: return Color(hex: "F5F5F5")
        }
    }
    
    var displayText: Color {
        switch self {
        case .dark, .midnight: return Color(hex: "FFB300")
        case .light: return Color(hex: "1A1A1A")
        }
    }
    
    var bodyColor: Color {
        switch self {
        case .dark: return Color(hex: "1C1C1E")
        case .midnight: return Color(hex: "0A0A12")
        case .light: return Color(hex: "E8E8EC")
        }
    }
    
    var buttonPrimary: Color {
        switch self {
        case .dark, .midnight: return Color(hex: "111111")
        case .light: return Color(hex: "FFFFFF")
        }
    }
    
    var buttonSecondary: Color {
        switch self {
        case .dark, .midnight: return Color(hex: "0D47A1")
        case .light: return Color(hex: "1565C0")
        }
    }
    
    var buttonAccent: Color {
        switch self {
        case .dark, .midnight: return Color(hex: "E65100")
        case .light: return Color(hex: "FF6D00")
        }
    }
    
    var textOnButton: Color {
        switch self {
        case .dark, .midnight: return .white
        case .light: return .white
        }
    }
    
    var textOnPrimary: Color {
        switch self {
        case .dark, .midnight: return .white
        case .light: return Color(hex: "1A1A1A")
        }
    }
}

enum AngleUnit: String, Codable, CaseIterable {
    case radians = "RAD"
    case degrees = "DEG"
    case gradians = "GRAD"
    
    func toRadians(_ value: Double) -> Double {
        switch self {
        case .radians: return value
        case .degrees: return value * .pi / 180
        case .gradians: return value * .pi / 200
        }
    }
    
    func fromRadians(_ value: Double) -> Double {
        switch self {
        case .radians: return value
        case .degrees: return value * 180 / .pi
        case .gradians: return value * 200 / .pi
        }
    }
}

enum FontSizeOption: String, Codable, CaseIterable {
    case small  = "Pequeño"
    case medium = "Mediano"
    case large  = "Grande"
    
    var scale: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.2
        }
    }
}

// MARK: - KeypadLayer

enum KeypadLayer: Int, CaseIterable {
    case basic = 0
    case scientific = 1
    case calculus = 2
    case advanced = 3
    
    var name: String {
        switch self {
        case .basic: return "Básico"
        case .scientific: return "Científico"
        case .calculus: return "Cálculo"
        case .advanced: return "Avanzado"
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
