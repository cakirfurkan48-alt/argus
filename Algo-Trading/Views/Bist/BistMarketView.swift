import SwiftUI

struct BistMarketView: View {
    @ObservedObject var viewModel: BistTradingViewModel
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    // Sabit BIST Listesi (Arama için basit filtreleme)
    // Gerçekte API'den arama yapılmalı ama şimdilik statik bir evren kullanacağız
    let universe = [
        "THYAO.IS": "Türk Hava Yolları",
        "ASELS.IS": "Aselsan",
        "KCHOL.IS": "Koç Holding",
        "AKBNK.IS": "Akbank",
        "GARAN.IS": "Garanti BBVA",
        "SAHOL.IS": "Sabancı Holding",
        "TUPRS.IS": "Tüpraş",
        "EREGL.IS": "Erdemir",
        "BIMAS.IS": "BİM Mağazaları",
        "SISE.IS": "Şişecam",
        "PETKM.IS": "Petkim",
        "SASA.IS": "SASA Polyester",
        "HEKTS.IS": "Hektaş",
        "FROTO.IS": "Ford Otosan",
        "TOASO.IS": "Tofaş",
        "ENKAI.IS": "Enka İnşaat",
        "ISCTR.IS": "İş Bankası (C)",
        "YKBNK.IS": "Yapı Kredi",
        "VAKBN.IS": "Vakıfbank",
        "HALKB.IS": "Halkbank",
        "PGSUS.IS": "Pegasus",
        "TAVHL.IS": "TAV Havalimanları",
        "TCELL.IS": "Turkcell",
        "TTKOM.IS": "Türk Telekom",
        "KOZAL.IS": "Koza Altın",
        "KOZAA.IS": "Koza Madencilik",
        "TKFEN.IS": "Tekfen Holding",
        "MGROS.IS": "Migros",
        "SOKM.IS": "Şok Marketler",
        "AEFES.IS": "Anadolu Efes",
        "ARCLK.IS": "Arçelik",
        "ALARK.IS": "Alarko Holding",
        "ASTOR.IS": "Astor Enerji",
        "BBRYO.IS": "Borsa Birleşik Varlık",
        "BRSAN.IS": "Borousan Mannesmann",
        "CIMSA.IS": "Çimsa",
        "DOAS.IS": "Doğuş Otomotiv",
        "EGEEN.IS": "Ege Endüstri",
        "EKGYO.IS": "Emlak Konut GYO",
        "ENJSA.IS": "Enerjisa",
        "GESAN.IS": "Girişim Elektrik",
        "KONTR.IS": "Kontrolmatik",
        "ODAS.IS": "Odaş Elektrik",
        "OYAKC.IS": "Oyak Çimento",
        "SMRTG.IS": "Smart Güneş Enerjisi",
        "ULKER.IS": "Ülker Bisküvi",
        "VESTL.IS": "Vestel Elektronik",
        "YEOTK.IS": "Yeo Teknoloji",
        "GUBRF.IS": "Gübre Fabrikaları",
        "ISMEN.IS": "İş Yatırım"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("BIST Hissesi Ara (örn: THYAO)", text: $searchText)
                }
                .padding()
                .background(Theme.secondaryBackground)
                .cornerRadius(12)
                .padding()
                
                List {
                    // Watchlist Section
                    if searchText.isEmpty {
                        Section(header: Text("Takiip Listem")) {
                            ForEach(viewModel.watchlist, id: \.self) { symbol in
                                BistTickerRow(
                                    symbol: symbol,
                                    name: universe[symbol] ?? symbol,
                                    quote: viewModel.quotes[symbol],
                                    orionResult: viewModel.analysisResults[symbol],
                                    onBuy: {
                                        // Hızlı Al (1 adet) - Test için
                                        viewModel.buy(symbol: symbol, quantity: 1)
                                    },
                                    onAppear: {
                                        Task { await viewModel.runOrionAnalysis(symbol: symbol) }
                                    }
                                )
                            }
                            .onDelete(perform: deleteFromWatchlist)
                        }
                    }
                    
                    // Search Results
                    if !searchText.isEmpty {
                        Section(header: Text("Arama Sonuçları")) {
                            ForEach(filteredSymbols, id: \.self) { symbol in
                                BistTickerRow(
                                    symbol: symbol,
                                    name: universe[symbol] ?? symbol,
                                    quote: viewModel.quotes[symbol],
                                    orionResult: viewModel.analysisResults[symbol],
                                    onBuy: {
                                        if !viewModel.watchlist.contains(symbol) {
                                            viewModel.watchlist.append(symbol)
                                            viewModel.saveWatchlist()
                                        }
                                        viewModel.buy(symbol: symbol, quantity: 1)
                                    },
                                    onAppear: {
                                        Task { await viewModel.runOrionAnalysis(symbol: symbol) }
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("BIST Piyasa")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    var filteredSymbols: [String] {
        if searchText.isEmpty { return [] }
        return universe.keys.filter {
            $0.contains(searchText.uppercased()) ||
            (universe[$0]?.uppercased().contains(searchText.uppercased()) ?? false)
        }.sorted()
    }
    
    func deleteFromWatchlist(at offsets: IndexSet) {
        viewModel.watchlist.remove(atOffsets: offsets)
        viewModel.saveWatchlist()
    }
}

struct BistTickerRow: View {
    let symbol: String
    let name: String
    let quote: BistTicker?
    let orionResult: OrionBistResult?
    let onBuy: () -> Void
    var onAppear: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(symbol.replacingOccurrences(of: ".IS", with: ""))
                        .font(.headline)
                        .bold()
                    
                    if let result = orionResult {
                        Text(result.signal.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(orionColor(result.signal))
                            .cornerRadius(4)
                    }
                }
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let q = quote {
                VStack(alignment: .trailing) {
                    Text("₺\(String(format: "%.2f", q.price))")
                        .bold()
                    
                    Text("\(q.change >= 0 ? "+" : "")%\(String(format: "%.2f", q.changePercent))")
                        .font(.caption)
                        .foregroundColor(q.isPositive ? .green : .red)
                        .padding(4)
                        .background(q.isPositive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(4)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            // Hızlı Al Butonu (Test Basitliği)
            Button(action: onBuy) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.tint)
            }
            .buttonStyle(BorderlessButtonStyle()) // Row içinde buton çalışması için
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
        .onAppear {
            onAppear?()
        }
    }
    
    func orionColor(_ signal: OrionBistSignal) -> Color {
        switch signal {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .orange
        }
    }
}
