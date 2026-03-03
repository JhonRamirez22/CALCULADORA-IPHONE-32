// AppState.swift
// CalcPrime — MathDF iOS
// Central observable state: navigation, history, settings, shared engine access.

import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Navigation
    @Published var navigationPath = NavigationPath()
    
    // MARK: - History
    @Published var history: [HistoryItem] = []
    
    // MARK: - Settings
    @Published var theme: AppTheme = .system {
        didSet { save() }
    }
    @Published var angleUnit: AngleUnit = .radians {
        didSet { save() }
    }
    @Published var defaultVariable: String = "x" {
        didSet { save() }
    }
    @Published var showStepsByDefault: Bool = true {
        didSet { save() }
    }
    @Published var derivativeNotation: DerivativeNotation = .prime {
        didSet { save() }
    }
    @Published var decimalPrecision: Int = 6 {
        didSet { save() }
    }
    
    // MARK: - Engine
    let engine = CASEngine.shared
    
    // MARK: - Computed
    var colorScheme: ColorScheme? {
        switch theme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
    
    // MARK: - Init
    init() {
        loadSettings()
        loadHistory()
    }
    
    // ═══════════════════════════════════════════
    // MARK: - History Operations
    // ═══════════════════════════════════════════
    
    func addToHistory(module: MathModule, input: String, resultLatex: String, resultPlain: String) {
        let item = HistoryItem(
            module: module,
            input: input,
            resultLatex: resultLatex,
            resultPlain: resultPlain
        )
        history.insert(item, at: 0)
        saveHistory()
    }
    
    func deleteHistoryItem(_ item: HistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func toggleFavorite(_ item: HistoryItem) {
        if let idx = history.firstIndex(where: { $0.id == item.id }) {
            history[idx] = history[idx].toggled()
            saveHistory()
        }
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    func filteredHistory(module: MathModule? = nil, search: String = "") -> [HistoryItem] {
        var items = history
        if let m = module {
            items = items.filter { $0.module == m }
        }
        if !search.isEmpty {
            items = items.filter {
                $0.input.localizedCaseInsensitiveContains(search) ||
                $0.resultPlain.localizedCaseInsensitiveContains(search)
            }
        }
        return items
    }
    
    // ═══════════════════════════════════════════
    // MARK: - Persistence
    // ═══════════════════════════════════════════
    
    private let settingsKey = "mathdf_settings"
    private let historyKey = "mathdf_history"
    
    private func save() {
        let dict: [String: Any] = [
            "theme": theme.rawValue,
            "angleUnit": angleUnit.rawValue,
            "defaultVariable": defaultVariable,
            "showSteps": showStepsByDefault,
            "derivNotation": derivativeNotation.rawValue,
            "precision": decimalPrecision
        ]
        UserDefaults.standard.set(dict, forKey: settingsKey)
    }
    
    private func loadSettings() {
        guard let dict = UserDefaults.standard.dictionary(forKey: settingsKey) else { return }
        if let t = dict["theme"] as? String, let v = AppTheme(rawValue: t) { theme = v }
        if let a = dict["angleUnit"] as? String, let v = AngleUnit(rawValue: a) { angleUnit = v }
        if let d = dict["defaultVariable"] as? String { defaultVariable = d }
        if let s = dict["showSteps"] as? Bool { showStepsByDefault = s }
        if let n = dict["derivNotation"] as? String, let v = DerivativeNotation(rawValue: n) { derivativeNotation = v }
        if let p = dict["precision"] as? Int { decimalPrecision = p }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = items
        }
    }
}
