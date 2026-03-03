// HistoryView.swift
// CalcPrime — Views
// Searchable, filterable calculation history with favorites.

import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: CalculationCategory?
    
    var filteredHistory: [HistoryEntry] {
        var items = appState.history
        
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        
        if !searchText.isEmpty {
            items = items.filter {
                $0.input.localizedCaseInsensitiveContains(searchText) ||
                $0.output.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("Todos", selected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        filterChip("★", selected: false) {
                            // Show favorites
                        }
                        ForEach(CalculationCategory.allCases, id: \.rawValue) { cat in
                            filterChip(cat.rawValue, selected: selectedCategory == cat) {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // List
                if filteredHistory.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Sin historial")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredHistory) { entry in
                            historyRow(entry)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        appState.deleteHistoryEntry(entry)
                                    } label: {
                                        Label("Borrar", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        appState.toggleFavorite(entry)
                                    } label: {
                                        Label("Favorito", systemImage: entry.isFavorite ? "star.slash" : "star.fill")
                                    }
                                    .tint(.yellow)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Buscar en historial")
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Borrar todo", role: .destructive) {
                        appState.clearHistory()
                    }
                    .font(.system(size: 13))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - History Row
    
    private func historyRow(_ entry: HistoryEntry) -> some View {
        Button {
            appState.recallHistoryEntry(entry)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: entry.category.icon)
                        .font(.system(size: 12))
                        .foregroundColor(entry.category.color)
                    
                    Text(entry.input)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }
                
                Text("= \(entry.output)")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                
                Text(entry.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Filter Chip
    
    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: selected ? .bold : .regular))
                .foregroundColor(selected ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.orange : Color.gray.opacity(0.2))
                .cornerRadius(16)
        }
    }
}
