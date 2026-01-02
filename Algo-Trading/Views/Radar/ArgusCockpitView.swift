import SwiftUI

// MARK: - TRADER TERMINAL VIEW

// Global Scope Enum
enum MarketTab {
    case global
    case bist
}

struct ArgusCockpitView: View {
    @EnvironmentObject var viewModel: TradingViewModel
    
    // Terminal State
    @State private var sortOption: TerminalSortOption = .councilScore
    @State private var hideLowQualityData: Bool = true
    @State private var searchText: String = ""
    @State private var selectedMarket: MarketTab = .global // Tab State
    
    // Overlay State
    @State private var selectedSymbolForModule: String? = nil
    @State private var selectedModuleType: ArgusSanctumView.ModuleType? = nil
    
    // Sort Options
    enum TerminalSortOption: String, CaseIterable, Identifiable {
        case councilScore = "Konsey / Divan"
        case orion = "Orion / Tahta"
        case atlas = "Atlas / Kasa"
        case potential = "Potansiyel"
        
        var id: String { rawValue }
    }
    
    // Filtered & Sorted List
    var terminalData: [String] {
        var symbols = viewModel.watchlist
        
        if !searchText.isEmpty {
            symbols = symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        if hideLowQualityData {
            symbols = symbols.filter { symbol in
                let health = viewModel.dataHealthBySymbol[symbol]?.qualityScore ?? 0
                return health >= 50
            }
        }
        
        symbols.sort { sym1, sym2 in
            switch sortOption {
            case .councilScore:
                let s1 = viewModel.grandDecisions[sym1]?.confidence ?? 0
                let s2 = viewModel.grandDecisions[sym2]?.confidence ?? 0
                return s1 > s2
                
            case .orion:
                let s1 = viewModel.orionScores[sym1]?.score ?? 0
                let s2 = viewModel.orionScores[sym2]?.score ?? 0
                return s1 > s2
                
            case .atlas:
                let s1 = viewModel.getFundamentalScore(for: sym1)?.totalScore ?? 0
                let s2 = viewModel.getFundamentalScore(for: sym2)?.totalScore ?? 0
                return s1 > s2
                
            case .potential:
                return sym1 < sym2
            }
        }
        
        return symbols
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    // Control Bar
                    TerminalControlBar(
                        sortOption: $sortOption,
                        hideLowQualityData: $hideLowQualityData,
                        count: terminalData.count,
                        selectedMarket: selectedMarket
                    )
                    
                    // Terminal List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if terminalData.isEmpty {
                                ContentUnavailableView(
                                    "Veri Bulunamadı",
                                    systemImage: "antenna.radiowaves.left.and.right.slash",
                                    description: Text("Kriterlere uygun hisse senedi yok.")
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(terminalData, id: \.self) { symbol in
                                    NavigationLink(destination: StockDetailView(symbol: symbol, viewModel: viewModel)) {
                                        TerminalStockRow(
                                            symbol: symbol,
                                            viewModel: viewModel,
                                            onOrionTap: {
                                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                    selectedSymbolForModule = symbol
                                                    selectedModuleType = .orion
                                                }
                                            },
                                            onAtlasTap: {
                                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                    selectedSymbolForModule = symbol
                                                    selectedModuleType = .atlas
                                                }
                                            }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .background(Color(hex: "080b14").ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 4) {
                            Image(systemName: selectedMarket == .bist ? "building.columns.fill" : "globe")
                                .foregroundColor(selectedMarket == .bist ? .red : .cyan)
                            Text(selectedMarket == .bist ? "SİRKİYE KOKPİTİ" : "GLOBAL TERMINAL")
                                .font(.system(.headline, design: .monospaced))
                                .bold()
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            
            // Holo Overlay
            if let module = selectedModuleType, let symbol = selectedSymbolForModule {
                ModuleHoloSheet(
                    module: module,
                    viewModel: viewModel,
                    symbol: symbol,
                    onClose: {
                        withAnimation {
                            selectedModuleType = nil
                            selectedSymbolForModule = nil
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .task {
            await viewModel.bootstrapTerminalData()
        }
    }
    
    // Tab Button Helper
    @ViewBuilder
    func tabButton(title: String, tab: MarketTab) -> some View {
        Button(action: { withAnimation { selectedMarket = tab } }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(selectedMarket == tab ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                
                Rectangle()
                    .fill(selectedMarket == tab ? (tab == .bist ? Color.red : Color.cyan) : Color.clear)
                    .frame(height: 2)
            }
        }
    }
}

// MARK: - SUBCOMPONENTS

struct TerminalControlBar: View {
    @Binding var sortOption: ArgusCockpitView.TerminalSortOption
    @Binding var hideLowQualityData: Bool
    let count: Int
    let selectedMarket: MarketTab // Updated Type
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(count) \(selectedMarket == .bist ? "HİSSE" : "TICKER")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Menu {
                    Picker("Sıralama", selection: $sortOption) {
                        ForEach(ArgusCockpitView.TerminalSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                        // Dynamic Sort Labels based on Market
                        Text(sortLabel(for: sortOption))
                            .font(.caption)
                            .bold()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundColor(selectedMarket == .bist ? .red : .cyan)
                }
            }
            
            HStack {
                Toggle(isOn: $hideLowQualityData) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(hideLowQualityData ? .orange : .gray)
                        Text("Düşük Kaliteyi Gizle")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(hex: "10141f"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.05)), alignment: .bottom)
    }
    
    func sortLabel(for option: ArgusCockpitView.TerminalSortOption) -> String {
        guard selectedMarket == .bist else { return option.rawValue }
        switch option {
        case .councilScore: return "Divan Puanı"
        case .orion: return "Tahta (Teknik)"
        case .atlas: return "Kasa (Temel)"
        case .potential: return "Potansiyel"
        }
    }
}

struct TerminalStockRow: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    var onOrionTap: () -> Void
    var onAtlasTap: () -> Void
    
    // Metric Accessors
    var orionScore: Double { viewModel.orionScores[symbol]?.score ?? 0 }
    var atlasScore: Double { viewModel.getFundamentalScore(for: symbol)?.totalScore ?? 0 }
    var councilScore: Double { (viewModel.grandDecisions[symbol]?.confidence ?? 0) * 100 }
    var dataHealth: Int { viewModel.dataHealthBySymbol[symbol]?.qualityScore ?? 0 }
    
    var action: ArgusAction {
        viewModel.grandDecisions[symbol]?.action ?? .neutral
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Ticker & Price
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(symbol.replacingOccurrences(of: ".IS", with: ""))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if symbol.uppercased().hasSuffix(".IS") {
                        Text("TR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                            .padding(2)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.red, lineWidth: 1))
                    }
                }
                
                if let quote = viewModel.quotes[symbol] {
                    let isBist = symbol.uppercased().hasSuffix(".IS")
                    Text(String(format: isBist ? "₺%.2f" : "$%.2f", quote.currentPrice))
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("---")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // Scores
            let isBist = symbol.uppercased().hasSuffix(".IS")
            HStack(spacing: 12) {
                Button(action: onOrionTap) {
                    // Orion (O) or Tahta (T)
                    TerminalScoreBadge(label: isBist ? "T" : "O", score: orionScore, color: .cyan)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onAtlasTap) {
                    // Atlas (A) or Kasa (K)
                    TerminalScoreBadge(label: isBist ? "K" : "A", score: atlasScore, color: .yellow)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Council (Star)
                TerminalScoreBadge(label: "★", score: councilScore, color: .green)
            }
            
            Spacer()
            
            // Action Signal
            VStack(alignment: .trailing, spacing: 4) {
                Text(actionLocalizedString(action))
                    .font(.system(size: 11, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(actionColor(action).opacity(0.2))
                    .foregroundColor(actionColor(action))
                    .cornerRadius(4)
                
                if dataHealth < 100 {
                    HStack(spacing: 2) {
                        Image(systemName: "wifi.exclamationmark")
                        Text("%\(dataHealth)")
                    }
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    func actionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return .green
        case .accumulate: return .mint
        case .neutral: return .gray
        case .trim: return .orange
        case .liquidate: return .red
        }
    }
    
    func actionLocalizedString(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "HÜCUM"
        case .accumulate: return "TOPLA"
        case .neutral: return "GÖZLE"
        case .trim: return "AZALT"
        case .liquidate: return "ÇIK"
        }
    }
}

// Terminal-specific simple score badge (doesn't use CompositeScore)
struct TerminalScoreBadge: View {
    let label: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                Text(score > 0 ? "\(Int(score))" : "-")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(score > 0 ? .white : .gray)
            }
        }
    }
}
