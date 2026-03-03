// HomeView.swift
// CalcPrime — MathDF iOS
// Main home screen with module grid + recent history.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var showAllModules = true
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private var filteredModules: [MathModule] {
        if searchText.isEmpty { return MathModule.allCases }
        return MathModule.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Quick access strip
                quickAccessStrip
                
                // Module Grid
                moduleGrid
                
                // Recent History
                if !appState.history.isEmpty {
                    recentHistorySection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    NavigationLink(value: "history" as String) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))
                    }
                    NavigationLink(value: "settings" as String) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MathDF")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(MathDFColors.accent)
            
            Text("Resuelve paso a paso")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // MARK: - Quick Access
    
    private var quickAccessStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MathModule.allCases, id: \.self) { module in
                    ModuleCardCompact(module: module) {
                        appState.navigationPath.append(module)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Module Grid
    
    private var moduleGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Módulos")
                    .font(.headline)
                
                Spacer()
                
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Buscar...", text: $searchText)
                        .font(.subheadline)
                        .frame(width: 120)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(.systemGray6))
                )
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredModules, id: \.self) { module in
                    ModuleCard(
                        module: module,
                        recentInput: lastInput(for: module)
                    ) {
                        appState.navigationPath.append(module)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent History
    
    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reciente")
                    .font(.headline)
                
                Spacer()
                
                Button("Ver todo") {
                    // Navigate to history
                    appState.navigationPath.append("history" as String)
                }
                .font(.subheadline)
                .foregroundColor(MathDFColors.accent)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(appState.history.prefix(5)) { item in
                    HistoryItemRow(item: item) {
                        // Navigate to the module with prefilled input
                        appState.navigationPath.append(item.module)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func lastInput(for module: MathModule) -> String? {
        appState.history.first(where: { $0.module == module })?.input
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: HistoryItem
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Module icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.module.accentColor.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: item.module.sfSymbol)
                        .font(.system(size: 14))
                        .foregroundColor(item.module.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.input)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(item.resultPlain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Timestamp
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState())
    }
}
