// StepsView.swift
// CalcPrime — Views
// Step-by-step solution display with expandable substeps and LaTeX rendering.

import SwiftUI

struct StepsView: View {
    let steps: [SolutionStepData]
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if steps.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.badge.xmark")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("No hay pasos disponibles")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            StepCard(step: step, index: index + 1, theme: theme)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "0A0A0F"))
            .navigationTitle("Solución paso a paso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        let text = LaTeXRenderer.formatSteps(steps)
                        ExportHelper.copyToClipboard(text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                    }
                }
            }
        }
    }
}

// MARK: - Step Card

struct StepCard: View {
    let step: SolutionStepData
    let index: Int
    let theme: AppTheme
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button { withAnimation { isExpanded.toggle() } } label: {
                HStack {
                    // Step number badge
                    Text("\(index)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(theme.buttonAccent))
                    
                    Text(step.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                // Explanation
                if !step.explanation.isEmpty {
                    Text(step.explanation)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(.leading, 36)
                }
                
                // Math expression
                if !step.math.isEmpty {
                    MathJaxInlineView(
                        latex: step.math,
                        textColor: "#FFB300",
                        fontSize: 16
                    )
                    .frame(height: 36)
                    .padding(.leading, 36)
                }
                
                // Substeps
                if !step.substeps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(step.substeps) { sub in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.orange.opacity(0.7))
                                VStack(alignment: .leading, spacing: 2) {
                                    if !sub.title.isEmpty {
                                        Text(sub.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    if !sub.math.isEmpty {
                                        Text(sub.math)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.orange.opacity(0.8))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, 44)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
