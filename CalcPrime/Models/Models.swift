// Models.swift
// CalcPrime — MathDF iOS
// All shared data models: modules, history, steps, graph data, settings.

import Foundation
import SwiftUI

// MARK: - Math Module

enum MathModule: String, CaseIterable, Identifiable, Hashable, Codable {
    case integral   = "Integrales"
    case ode        = "EDO"
    case derivative = "Derivadas"
    case equation   = "Ecuaciones"
    case limit      = "Límites"
    case matrix     = "Matrices"
    case complex    = "Complejos"
    case numeric    = "Numérica"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .integral:   return "∫"
        case .ode:        return "y'"
        case .derivative: return "d/dx"
        case .equation:   return "f(x)=0"
        case .limit:      return "lim"
        case .matrix:     return "[A]"
        case .complex:    return "a+bi"
        case .numeric:    return "≈"
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .integral:   return "sum"
        case .ode:        return "waveform.path.ecg"
        case .derivative: return "arrow.up.right"
        case .equation:   return "equal"
        case .limit:      return "arrow.right"
        case .matrix:     return "square.grid.3x3"
        case .complex:    return "point.topleft.down.to.point.bottomright.curvepath"
        case .numeric:    return "number"
        }
    }
    
    var description: String {
        switch self {
        case .integral:   return "Integrales definidas e indefinidas"
        case .ode:        return "Ecuaciones diferenciales"
        case .derivative: return "Derivadas de orden n"
        case .equation:   return "Resolver ecuaciones y sistemas"
        case .limit:      return "Límites y continuidad"
        case .matrix:     return "Operaciones con matrices"
        case .complex:    return "Números complejos"
        case .numeric:    return "Evaluación numérica"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .integral:   return Color(hex: "4A90D9")
        case .ode:        return Color(hex: "E74C3C")
        case .derivative: return Color(hex: "F39C12")
        case .equation:   return Color(hex: "27AE60")
        case .limit:      return Color(hex: "8E44AD")
        case .matrix:     return Color(hex: "16A085")
        case .complex:    return Color(hex: "2980B9")
        case .numeric:    return Color(hex: "D35400")
        }
    }
}

// MARK: - Solution Step

struct SolutionStepData: Identifiable, Codable, Hashable {
    let id: UUID
    let index: Int
    let groupTitle: String?
    let methodName: String
    let expressionLatex: String
    let explanation: String
    let isKeyStep: Bool
    let substeps: [SolutionStepData]
    
    init(index: Int, groupTitle: String? = nil, methodName: String = "",
         expressionLatex: String, explanation: String = "",
         isKeyStep: Bool = false, substeps: [SolutionStepData] = []) {
        self.id = UUID()
        self.index = index
        self.groupTitle = groupTitle
        self.methodName = methodName
        self.expressionLatex = expressionLatex
        self.explanation = explanation
        self.isKeyStep = isKeyStep
        self.substeps = substeps
    }
    
    /// Convert from CAS engine SolutionStep
    static func fromEngine(_ step: SolutionStep, index: Int, group: String? = nil) -> SolutionStepData {
        SolutionStepData(
            index: index,
            groupTitle: group,
            methodName: step.title,
            expressionLatex: step.math,
            explanation: step.explanation,
            isKeyStep: false,
            substeps: step.substeps.enumerated().map { i, s in
                fromEngine(s, index: i + 1, group: nil)
            }
        )
    }
    
    /// Convert a full array from CAS result
    static func fromEngineSteps(_ steps: [SolutionStep]) -> [SolutionStepData] {
        steps.enumerated().map { i, s in fromEngine(s, index: i + 1) }
    }
}

// MARK: - History Item

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let module: MathModule
    let input: String
    let resultLatex: String
    let resultPlain: String
    let timestamp: Date
    var isFavorite: Bool
    
    init(module: MathModule, input: String, resultLatex: String,
         resultPlain: String, isFavorite: Bool = false) {
        self.id = UUID()
        self.module = module
        self.input = input
        self.resultLatex = resultLatex
        self.resultPlain = resultPlain
        self.timestamp = Date()
        self.isFavorite = isFavorite
    }
    
    func toggled() -> HistoryItem {
        var copy = self
        copy.isFavorite = !isFavorite
        return copy
    }
}

// MARK: - Graph Data

struct GraphData {
    let function: (Double) -> Double
    let label: String
    let color: Color
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>?
    
    init(function: @escaping (Double) -> Double, label: String = "f(x)",
         color: Color = .blue, xRange: ClosedRange<Double> = -10...10,
         yRange: ClosedRange<Double>? = nil) {
        self.function = function
        self.label = label
        self.color = color
        self.xRange = xRange
        self.yRange = yRange
    }
}

// MARK: - Validation State

enum ValidationState: Equatable {
    case empty
    case valid
    case invalid(String)
    
    var color: Color {
        switch self {
        case .empty:      return .gray
        case .valid:      return MathDFColors.validGreen
        case .invalid:    return MathDFColors.errorRed
        }
    }
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

// MARK: - Angle Unit

enum AngleUnit: String, Codable, CaseIterable {
    case radians  = "Radianes"
    case degrees  = "Grados"
    
    func toRadians(_ value: Double) -> Double {
        switch self {
        case .radians: return value
        case .degrees: return value * .pi / 180
        }
    }
}

// MARK: - Derivative Notation

enum DerivativeNotation: String, Codable, CaseIterable {
    case prime   = "y'"
    case leibniz = "dy/dx"
    case d       = "Dy"
}

// MARK: - App Theme

enum AppTheme: String, Codable, CaseIterable {
    case light  = "Claro"
    case dark   = "Oscuro"
    case system = "Sistema"
}

// MARK: - MathDF Colors

struct MathDFColors {
    // Light mode primary
    static let background    = Color(hex: "FFFFFF")
    static let surface       = Color(hex: "F5F5F5")
    static let accent        = Color(hex: "4A90D9")
    static let accentLight   = Color(hex: "E8F0FE")
    static let solveButton   = Color(hex: "4A90D9")
    static let textPrimary   = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "666666")
    static let stepBorder    = Color(hex: "E0E0E0")
    static let validGreen    = Color(hex: "2E7D32")
    static let errorRed      = Color(hex: "C62828")
    static let highlight     = Color(hex: "FFF9C4")
    static let cardShadow    = Color.black.opacity(0.06)
    
    // Dark mode overrides handled by Color assets / environment
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
