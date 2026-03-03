// AppState.swift
// CalcPrime — Models
// Central observable state object for the entire app.

import Foundation
import SwiftUI
import Combine

// MARK: - AppState

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Display
    @Published var currentInput: String = ""
    @Published var displayLines: [DisplayLine] = []
    @Published var currentResult: CalculationResult?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Keypad
    @Published var currentLayer: KeypadLayer = .basic
    @Published var isShiftActive: Bool = false
    @Published var isAlphaActive: Bool = false
    
    // MARK: - Mode
    @Published var currentMode: CalculatorMode = .calculator
    @Published var angleUnit: AngleUnit = .radians
    
    // MARK: - History
    @Published var history: [HistoryEntry] = []
    @Published var showHistory: Bool = false
    
    // MARK: - Steps
    @Published var showSteps: Bool = false
    @Published var currentSteps: [SolutionStepData] = []
    
    // MARK: - Preferences
    @Published var preferences: UserPreferences = .default {
        didSet { savePreferences() }
    }
    
    // MARK: - Engine
    let engine = CASEngine.shared
    
    // MARK: - Init
    
    init() {
        loadPreferences()
        loadHistory()
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Input Handling
    // ─────────────────────────────────────────────
    
    func appendInput(_ text: String) {
        errorMessage = nil
        currentInput += text
    }
    
    func deleteLastCharacter() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
    }
    
    func clearInput() {
        currentInput = ""
        errorMessage = nil
    }
    
    func clearAll() {
        currentInput = ""
        displayLines = []
        currentResult = nil
        currentSteps = []
        errorMessage = nil
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Evaluation
    // ─────────────────────────────────────────────
    
    func evaluate() {
        let input = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let casResult = try engine.process(input)
                let category = detectCategory(input)
                let result = CalculationResult.from(casResult, category: category)
                
                self.currentResult = result
                self.displayLines.append(DisplayLine(input: input, output: result.output,
                                                     latex: result.latex))
                self.currentSteps = result.steps
                
                // Save to history
                let entry = HistoryEntry.from(result)
                self.history.insert(entry, at: 0)
                if self.history.count > self.preferences.historyLimit {
                    self.history = Array(self.history.prefix(self.preferences.historyLimit))
                }
                saveHistory()
                
                self.currentInput = ""
                self.isProcessing = false
            } catch {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    /// Detect calculation category from input string.
    private func detectCategory(_ input: String) -> CalculationCategory {
        let lower = input.lowercased()
        if lower.contains("∫") || lower.contains("integral") || lower.contains("integrate") {
            return .integral
        }
        if lower.contains("d/d") || lower.contains("derivat") || lower.contains("diff") {
            return .derivative
        }
        if lower.contains("factor") { return .factorization }
        if lower.contains("solve") || lower.contains("=") { return .equation }
        if lower.contains("ode") || lower.contains("y'") { return .ode }
        if lower.contains("pde") || lower.contains("∂") { return .pde }
        if lower.contains("matrix") || lower.contains("det") || lower.contains("eigen") { return .linearAlgebra }
        if lower.contains("taylor") || lower.contains("series") || lower.contains("fourier") { return .series }
        if lower.contains("laplace") || lower.contains("transform") { return .transform }
        return .general
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Keypad Layer
    // ─────────────────────────────────────────────
    
    func nextLayer() {
        let allCases = KeypadLayer.allCases
        let idx = (currentLayer.rawValue + 1) % allCases.count
        currentLayer = allCases[idx]
    }
    
    func previousLayer() {
        let allCases = KeypadLayer.allCases
        let idx = (currentLayer.rawValue - 1 + allCases.count) % allCases.count
        currentLayer = allCases[idx]
    }
    
    func toggleShift() { isShiftActive.toggle() }
    func toggleAlpha() { isAlphaActive.toggle() }
    
    // ─────────────────────────────────────────────
    // MARK: - History
    // ─────────────────────────────────────────────
    
    func deleteHistoryEntry(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
        saveHistory()
    }
    
    func toggleFavorite(_ entry: HistoryEntry) {
        if let idx = history.firstIndex(where: { $0.id == entry.id }) {
            history[idx] = history[idx].toggleFavorite()
            saveHistory()
        }
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    func recallHistoryEntry(_ entry: HistoryEntry) {
        currentInput = entry.input
        showHistory = false
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Persistence
    // ─────────────────────────────────────────────
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "calcprime_preferences")
        }
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "calcprime_preferences"),
           let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = prefs
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "calcprime_history")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "calcprime_history"),
           let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            history = saved
        }
    }
}

// MARK: - CalculatorMode

enum CalculatorMode: String, CaseIterable, Identifiable {
    case calculator = "Calculadora"
    case cas        = "CAS"
    case graphing   = "Gráficas"
    case modules    = "Módulos"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .calculator: return "plus.forwardslash.minus"
        case .cas: return "function"
        case .graphing: return "chart.xyaxis.line"
        case .modules: return "square.grid.2x2"
        }
    }
}

// MARK: - DisplayLine

struct DisplayLine: Identifiable {
    let id = UUID()
    let input: String
    let output: String
    let latex: String
    let timestamp = Date()
}
