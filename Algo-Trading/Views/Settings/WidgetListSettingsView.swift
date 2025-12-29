import SwiftUI

struct WidgetListSettingsView: View {
    @State private var config: WidgetConfig = ArgusStorage.shared.loadWidgetConfig() ?? WidgetConfig(symbols: ["AAPL", "BTC-USD", "ETH-USD", "NVDA"])
    @State private var newSymbol: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Widget İçeriği")) {
                Text("Widget'ta gösterilecek sembolleri düzenleyin (Maks 6).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                List {
                    ForEach(config.symbols, id: \.self) { symbol in
                        Text(symbol.uppercased())
                    }
                    .onDelete(perform: deleteSymbol)
                }
                
                HStack {
                    TextField("Sembol Ekle (Örn: AAPL)", text: $newSymbol)
                        .autocapitalization(.allCharacters)
                    
                    Button(action: addSymbol) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.tint)
                    }
                    .disabled(newSymbol.isEmpty || config.symbols.count >= 6)
                }
            }
            
            Section(header: Text("Görünüm")) {
                Toggle("Orion Sinyal Rozeti", isOn: $config.showOrionBadge)
            }
        }
        .navigationTitle("Widget Ayarları")
        .onChange(of: config) { _, newValue in
            saveConfig()
        }
        .onDisappear {
            saveConfig()
        }
    }
    
    private func addSymbol() {
        let sym = newSymbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !sym.isEmpty && !config.symbols.contains(sym) {
            withAnimation {
                config.symbols.append(sym)
                newSymbol = ""
            }
        }
    }
    
    private func deleteSymbol(at offsets: IndexSet) {
        config.symbols.remove(atOffsets: offsets)
    }
    
    private func saveConfig() {
        // Update timestamp
        var toSave = config
        toSave.lastUpdated = Date()
        ArgusStorage.shared.saveWidgetConfig(toSave)
        print("✅ Widget Config Saved: \(toSave.symbols)")
        
        // In a real app with WidgetKit linked, we would call:
        // WidgetCenter.shared.reloadAllTimelines()
    }
}
