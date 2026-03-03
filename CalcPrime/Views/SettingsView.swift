// SettingsView.swift
// CalcPrime — Views
// User preferences: theme, angle unit, precision, etc.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // ── Apariencia ──
                Section("Apariencia") {
                    Picker("Tema", selection: $appState.preferences.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    
                    Picker("Tamaño de fuente", selection: $appState.preferences.fontSize) {
                        ForEach(FontSizeOption.allCases, id: \.rawValue) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                }
                
                // ── Cálculo ──
                Section("Cálculo") {
                    Picker("Unidad angular", selection: $appState.preferences.angleUnit) {
                        ForEach(AngleUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    Stepper("Precisión: \(appState.preferences.precision) decimales",
                            value: $appState.preferences.precision, in: 2...15)
                    
                    Toggle("Simplificar automáticamente", isOn: $appState.preferences.autoSimplify)
                    
                    Toggle("Mostrar pasos", isOn: $appState.preferences.showSteps)
                    
                    Picker("Variable por defecto", selection: $appState.preferences.defaultVariable) {
                        Text("x").tag("x")
                        Text("t").tag("t")
                        Text("z").tag("z")
                    }
                }
                
                // ── Experiencia ──
                Section("Experiencia") {
                    Toggle("Vibración háptica", isOn: $appState.preferences.hapticFeedback)
                    Toggle("Efectos de sonido", isOn: $appState.preferences.soundEffects)
                    
                    Stepper("Límite historial: \(appState.preferences.historyLimit)",
                            value: $appState.preferences.historyLimit, in: 50...2000, step: 50)
                }
                
                // ── Historial ──
                Section("Datos") {
                    Button("Borrar historial", role: .destructive) {
                        appState.clearHistory()
                    }
                    
                    Button("Restaurar configuración") {
                        appState.preferences = .default
                    }
                }
                
                // ── Acerca de ──
                Section("Acerca de") {
                    HStack {
                        Text("CalcPrime")
                        Spacer()
                        Text("v2.0")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Motor CAS")
                        Spacer()
                        Text("Swift Native")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Renderizado")
                        Spacer()
                        Text("MathJax 3")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
