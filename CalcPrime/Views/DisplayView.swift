// DisplayView.swift
// CalcPrime — Views
// Calculator display: shows input, result (MathJax LaTeX), and scrollable history.

import SwiftUI

struct DisplayView: View {
    @ObservedObject var appState: AppState
    
    var theme: AppTheme { appState.preferences.theme }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Scrollable History ──
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .trailing, spacing: 8) {
                        ForEach(appState.displayLines) { line in
                            VStack(alignment: .trailing, spacing: 2) {
                                // Input line
                                Text(line.input)
                                    .font(.system(size: 16, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                
                                // Result in LaTeX
                                if !line.latex.isEmpty {
                                    MathJaxView(
                                        latex: line.latex,
                                        textColor: hexString(theme.displayText),
                                        fontSize: 20 * appState.preferences.fontSize.scale,
                                        backgroundColor: hexString(theme.displayBackground)
                                    )
                                    .frame(height: 40)
                                } else {
                                    Text(line.output)
                                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                        .foregroundColor(theme.displayText)
                                }
                            }
                            .id(line.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .onChange(of: appState.displayLines.count) { _ in
                    if let last = appState.displayLines.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // ── Current Input Line ──
            HStack {
                Spacer()
                
                Text(appState.currentInput.isEmpty ? "0" : appState.currentInput)
                    .font(.system(size: 28 * appState.preferences.fontSize.scale,
                                  weight: .light, design: .monospaced))
                    .foregroundColor(appState.currentInput.isEmpty ? .gray.opacity(0.5) : .white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .animation(.easeOut(duration: 0.1), value: appState.currentInput)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            // ── Error Message ──
            if let error = appState.errorMessage {
                HStack {
                    Spacer()
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .transition(.opacity)
            }
            
            // ── Action Bar ──
            actionBar
        }
        .background(theme.displayBackground)
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: 12) {
            // Steps button
            if !appState.currentSteps.isEmpty {
                Button {
                    appState.showSteps = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number")
                        Text("Pasos")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
            }
            
            Spacer()
            
            // Copy button
            if appState.currentResult != nil {
                Button {
                    if let result = appState.currentResult {
                        ExportHelper.copyToClipboard(result.output)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Share button
                Button {
                    if let result = appState.currentResult {
                        let text = ExportHelper.export(result, format: .plainText) as? String ?? ""
                        ExportHelper.share([text])
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // MARK: - Helper
    
    private func hexString(_ color: Color) -> String {
        // Approximate hex from known theme colors
        switch appState.preferences.theme {
        case .dark: return "#FFB300"
        case .midnight: return "#FFB300"
        case .light: return "#1A1A1A"
        }
    }
}
