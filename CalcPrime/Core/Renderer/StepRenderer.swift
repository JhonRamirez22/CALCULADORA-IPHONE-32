// StepRenderer.swift
// CalcPrime — MathDF iOS
// Renders step-by-step solutions exactly like MathDF: numbered steps,
// collapsible groups, LaTeX via MathJax, key step highlighting.

import SwiftUI

// MARK: - Step-by-Step View

struct StepByStepView: View {
    let steps: [SolutionStepData]
    var accentColor: Color = MathDFColors.accent
    
    @State private var expandedGroups: Set<String> = []
    @State private var showAll = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(accentColor)
                Text("Solución paso a paso")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(showAll ? "Colapsar" : "Expandir") {
                    withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                }
                .font(.system(size: 13))
                .foregroundStyle(accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showAll {
                Divider()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let grouped = groupSteps(steps)
                        ForEach(Array(grouped.enumerated()), id: \.offset) { groupIdx, group in
                            if let title = group.title {
                                GroupHeader(
                                    title: title,
                                    isExpanded: expandedGroups.contains(title),
                                    accentColor: accentColor
                                ) {
                                    toggleGroup(title)
                                }
                                
                                if expandedGroups.contains(title) || expandedGroups.isEmpty {
                                    ForEach(group.steps) { step in
                                        StepRow(step: step, accentColor: accentColor)
                                    }
                                }
                            } else {
                                ForEach(group.steps) { step in
                                    StepRow(step: step, accentColor: accentColor)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .background(colorScheme == .dark ? Color(hex: "1C1C1E") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .onAppear {
            // Auto-expand all groups initially
            let titles = steps.compactMap { $0.groupTitle }
            expandedGroups = Set(titles)
        }
    }
    
    private func toggleGroup(_ title: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedGroups.contains(title) {
                expandedGroups.remove(title)
            } else {
                expandedGroups.insert(title)
            }
        }
    }
    
    // Group steps by groupTitle
    private func groupSteps(_ steps: [SolutionStepData]) -> [StepGroup] {
        var groups: [StepGroup] = []
        var currentGroup: StepGroup?
        
        for step in steps {
            if let title = step.groupTitle {
                if currentGroup?.title != title {
                    if let g = currentGroup { groups.append(g) }
                    currentGroup = StepGroup(title: title, steps: [step])
                } else {
                    currentGroup?.steps.append(step)
                }
            } else {
                if let g = currentGroup { groups.append(g); currentGroup = nil }
                groups.append(StepGroup(title: nil, steps: [step]))
            }
        }
        if let g = currentGroup { groups.append(g) }
        
        return groups
    }
}

// MARK: - Step Group

private struct StepGroup {
    let title: String?
    var steps: [SolutionStepData]
}

// MARK: - Group Header

private struct GroupHeader: View {
    let title: String
    let isExpanded: Bool
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4, height: 24)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.05))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let step: SolutionStepData
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme
    @State private var showSubsteps = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                // Step number circle
                ZStack {
                    Circle()
                        .fill(step.isKeyStep ? accentColor : Color.gray.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Text("\(step.index)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(step.isKeyStep ? .white : .primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Method name
                    if !step.methodName.isEmpty {
                        Text(step.methodName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    
                    // LaTeX expression
                    if !step.expressionLatex.isEmpty {
                        MathJaxView(
                            latex: step.expressionLatex,
                            fontSize: 17,
                            displayMode: true,
                            textColor: colorScheme == .dark ? "#E0E0E0" : "#1A1A1A",
                            backgroundColor: step.isKeyStep
                                ? (colorScheme == .dark ? "#3E3E00" : "#FFF9C4")
                                : "transparent"
                        )
                        .frame(minHeight: 40, maxHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // Explanation
                    if !step.explanation.isEmpty {
                        Text(step.explanation)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Substeps toggle
                    if !step.substeps.isEmpty {
                        Button {
                            withAnimation { showSubsteps.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showSubsteps ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10))
                                Text("\(step.substeps.count) sub-pasos")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(accentColor)
                        }
                        
                        if showSubsteps {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(step.substeps) { sub in
                                    SubstepRow(step: sub, accentColor: accentColor)
                                }
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.leading, 38)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(step.isKeyStep ? Color.yellow.opacity(0.05) : .clear)
    }
}

// MARK: - Substep Row

private struct SubstepRow: View {
    let step: SolutionStepData
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 2) {
                if !step.expressionLatex.isEmpty {
                    MathJaxView(
                        latex: step.expressionLatex,
                        fontSize: 14,
                        displayMode: false,
                        textColor: colorScheme == .dark ? "#B0B0B0" : "#444444",
                        backgroundColor: "transparent"
                    )
                    .frame(height: 28)
                }
                if !step.explanation.isEmpty {
                    Text(step.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Copy Steps Helper

struct StepCopyHelper {
    static func asPlainText(_ steps: [SolutionStepData]) -> String {
        steps.map { step in
            var line = "Paso \(step.index)"
            if !step.methodName.isEmpty { line += " [\(step.methodName)]" }
            line += ": \(step.expressionLatex)"
            if !step.explanation.isEmpty { line += "\n  → \(step.explanation)" }
            return line
        }.joined(separator: "\n\n")
    }
    
    static func asLatex(_ steps: [SolutionStepData]) -> String {
        var lines: [String] = ["\\begin{align*}"]
        for step in steps {
            if !step.expressionLatex.isEmpty {
                lines.append("& \\text{Paso \(step.index): } \(step.expressionLatex) \\\\")
            }
        }
        lines.append("\\end{align*}")
        return lines.joined(separator: "\n")
    }
}
