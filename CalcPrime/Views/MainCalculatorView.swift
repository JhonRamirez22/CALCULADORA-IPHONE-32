// MainCalculatorView.swift
// CalcPrime — Views
// Root view: HP Prime G2-inspired layout with display + swipeable 4-layer keypad.

import SwiftUI

struct MainCalculatorView: View {
    @StateObject private var appState = AppState()
    @State private var showSettings = false
    @State private var showModules = false
    
    var theme: AppTheme { appState.preferences.theme }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.bodyColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topBar
                    
                    DisplayView(appState: appState)
                        .frame(height: geo.size.height * 0.38)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    
                    layerIndicator
                    
                    KeypadView(appState: appState)
                        .frame(maxHeight: .infinity)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(appState: appState)
            }
            .sheet(isPresented: $showModules) {
                ModulesMenuView(appState: appState)
            }
            .sheet(isPresented: $appState.showHistory) {
                HistoryView(appState: appState)
            }
            .sheet(isPresented: $appState.showSteps) {
                StepsView(steps: appState.currentSteps, theme: theme)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Menu {
                ForEach(CalculatorMode.allCases) { mode in
                    Button {
                        appState.currentMode = mode
                        if mode == .modules { showModules = true }
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: appState.currentMode.icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(appState.currentMode.rawValue)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(theme.displayText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            
            Spacer()
            
            Button {
                let units = AngleUnit.allCases
                let idx = ((units.firstIndex(of: appState.angleUnit) ?? 0) + 1) % units.count
                appState.angleUnit = units[idx]
            } label: {
                Text(appState.angleUnit.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Button { appState.showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 6)
            
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.bodyColor)
    }
    
    // MARK: - Layer Indicator
    
    private var layerIndicator: some View {
        HStack(spacing: 8) {
            ForEach(KeypadLayer.allCases, id: \.rawValue) { layer in
                VStack(spacing: 2) {
                    Circle()
                        .fill(layer == appState.currentLayer ? theme.buttonAccent : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text(layer.name)
                        .font(.system(size: 9, weight: layer == appState.currentLayer ? .bold : .regular))
                        .foregroundColor(layer == appState.currentLayer ? theme.displayText : .gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainCalculatorView()
}
