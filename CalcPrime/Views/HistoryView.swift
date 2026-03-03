// HistoryView.swift
// CalcPrime — MathDF iOS
// Browsable history with search, filter by module, favorites.

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var filterModule: MathModule?
    @State private var showFavoritesOnly = false
    @State private var showClearAlert = false
    
    private var filteredHistory: [HistoryItem] {
        var items = appState.history
        if showFavoritesOnly {
            items = items.filter(\.isFavorite)
        }
        if let module = filterModule {
            items = items.filter { $0.module == module }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.input.localizedCaseInsensitiveContains(searchText) ||
                $0.resultPlain.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters
            filterBar
            
            // List
            if filteredHistory.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Buscar en historial")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Toggle("Solo favoritos", isOn: $showFavoritesOnly)
                    Divider()
                    Button(role: .destructive) { showClearAlert = true } label: {
                        Label("Borrar todo", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("¿Borrar todo el historial?", isPresented: $showClearAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) { appState.clearHistory() }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "Todos", isSelected: filterModule == nil) {
                    filterModule = nil
                }
                ForEach(MathModule.allCases, id: \.self) { module in
                    filterChip(
                        label: module.rawValue,
                        icon: module.sfSymbol,
                        color: module.accentColor,
                        isSelected: filterModule == module
                    ) {
                        filterModule = filterModule == module ? nil : module
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func filterChip(label: String, icon: String? = nil, color: Color = MathDFColors.accent, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 10))
                }
                Text(label).font(.caption.bold())
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? color : color.opacity(0.1))
            )
        }
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        List {
            ForEach(filteredHistory) { item in
                HistoryDetailRow(item: item) {
                    appState.navigationPath.append(item.module)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        appState.toggleFavorite(item)
                    } label: {
                        Label(item.isFavorite ? "Quitar" : "Favorito",
                              systemImage: item.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        appState.deleteHistoryItem(item)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Sin historial")
                .font(.title3.bold()).foregroundColor(.secondary)
            Text("Resuelve problemas y aparecerán aquí")
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Detail Row

struct HistoryDetailRow: View {
    let item: HistoryItem
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: item.module.sfSymbol)
                            .font(.system(size: 12))
                            .foregroundColor(item.module.accentColor)
                        Text(item.module.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(item.module.accentColor)
                    }
                    
                    Spacer()
                    
                    if item.isFavorite {
                        Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow)
                    }
                    
                    Text(item.timestamp, style: .relative)
                        .font(.caption2).foregroundColor(.secondary)
                }
                
                Text(item.input)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text("=")
                        .font(.caption.bold()).foregroundColor(.secondary)
                    Text(item.resultPlain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { HistoryView().environmentObject(AppState()) }
}
