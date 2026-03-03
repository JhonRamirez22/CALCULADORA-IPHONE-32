// ModuleCard.swift
// CalcPrime — MathDF iOS
// Home screen card for each math module.

import SwiftUI

struct ModuleCard: View {
    let module: MathModule
    var recentInput: String? = nil
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(module.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: module.sfSymbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(module.accentColor)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Icon (large LaTeX-style)
                Text(module.icon)
                    .font(.system(size: 28))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Title
                Text(module.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Description
                Text(module.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Recent input chip (if exists)
                if let recent = recentInput {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                        Text(recent)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundColor(module.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(module.accentColor.opacity(0.1))
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: module.accentColor.opacity(isPressed ? 0.2 : 0.08),
                            radius: isPressed ? 8 : 6,
                            y: isPressed ? 2 : 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(module.accentColor.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Compact Card (for horizontal scrolling)

struct ModuleCardCompact: View {
    let module: MathModule
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(module.accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: module.sfSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(module.accentColor)
                }
                
                Text(module.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
        ModuleCard(module: .integral, recentInput: "∫sin(x)dx") {}
        ModuleCard(module: .derivative) {}
        ModuleCard(module: .equation) {}
        ModuleCard(module: .ode) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
