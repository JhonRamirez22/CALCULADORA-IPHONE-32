// SettingsView.swift
// CalcPrime — MathDF iOS
// App settings — theme, angle unit, precision, about.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            // Appearance
            Section("Apariencia") {
                Picker("Tema", selection: $appState.theme) {
                    Text("Sistema").tag(AppTheme.system)
                    Text("Claro").tag(AppTheme.light)
                    Text("Oscuro").tag(AppTheme.dark)
                }
                .pickerStyle(.segmented)
            }
            
            // Calculation
            Section("Cálculo") {
                Picker("Unidad angular", selection: $appState.angleUnit) {
                    Text("Radianes").tag(AngleUnit.radians)
                    Text("Grados").tag(AngleUnit.degrees)
                }
                
                HStack {
                    Text("Precisión decimal")
                    Spacer()
                    Text("\(appState.decimalPrecision)")
                        .foregroundColor(.secondary)
                    Stepper("", value: $appState.decimalPrecision, in: 1...30)
                        .frame(width: 100)
                }
                
                Picker("Variable por defecto", selection: $appState.defaultVariable) {
                    Text("x").tag("x")
                    Text("y").tag("y")
                    Text("t").tag("t")
                }
                
                Picker("Notación de derivada", selection: $appState.derivativeNotation) {
                    Text("Leibniz (dy/dx)").tag(DerivativeNotation.leibniz)
                    Text("Lagrange (y')").tag(DerivativeNotation.lagrange)
                    Text("Newton (ẏ)").tag(DerivativeNotation.newton)
                }
                
                Toggle("Mostrar pasos por defecto", isOn: $appState.showStepsByDefault)
            }
            
            // Data
            Section("Datos") {
                HStack {
                    Text("Historial")
                    Spacer()
                    Text("\(appState.history.count) registros")
                        .foregroundColor(.secondary)
                }
                
                Button(role: .destructive) {
                    appState.clearHistory()
                } label: {
                    Label("Borrar historial", systemImage: "trash")
                }
            }
            
            // About
            Section("Acerca de") {
                HStack {
                    Text("Versión")
                    Spacer()
                    Text("2.0.0").foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Motor CAS")
                    Spacer()
                    Text("CalcPrime Engine").foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://mathdf.com")!) {
                    HStack {
                        Text("Inspirado en MathDF.com")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                }
                
                Link(destination: URL(string: "https://github.com/JhonRamirez22/CALCULADORA-IPHONE-32")!) {
                    HStack {
                        Text("Código fuente")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
            
            // Credits
            Section {
                VStack(spacing: 4) {
                    Text("MathDF iOS")
                        .font(.headline)
                    Text("Desarrollado por Jhon Ramirez")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("CAS Engine con 23 módulos de cálculo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SettingsView().environmentObject(AppState())
    }
}
