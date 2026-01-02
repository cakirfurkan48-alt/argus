import SwiftUI

// MARK: - Atlas (Argus Core) Sheet
struct ArgusAtlasSheet: View {
    let score: FundamentalScoreResult?
    
    var body: some View {
        if let score = score {
            ScoreDetailsSheet(score: score)
        } else {
            NavigationView {
                Text("Veri Yok")
                    .navigationTitle("Argus Atlas")
            }
        }
    }
}

// MARK: - Orion Sheet
struct ArgusOrionSheet: View {
    let symbol: String
    let orion: OrionScoreResult?
    let candles: [Candle]?
    
    var body: some View {
        NavigationView {
            if let orion = orion {
                OrionDetailView(symbol: symbol, orion: orion, candles: candles)
            } else {
                Text("Veri Yok")
            }
        }
    }
}

// MARK: - Aether Sheet (Opens Full Educational Detail View)
struct ArgusAetherSheet: View {
    let macro: MacroEnvironmentRating?

    var body: some View {
        if let macro = macro {
            ArgusAetherDetailView(rating: macro)
        } else {
            NavigationView {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Aether Verileri Yükleniyor...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .navigationTitle("Aether")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Hermes Sheet
// MARK: - Hermes Sheet
struct ArgusHermesSheet: View {
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    var body: some View {
        HermesSheetView(viewModel: viewModel, symbol: symbol)
    }
}

// MARK: - Hermes Shared Views

struct HermesSheetView: View {
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    private var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // BIST Banner
                    if isBist {
                        HStack(spacing: 8) {
                            Text("🇹🇷")
                            Text("BIST Haber Taraması")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Investing.com TR")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // Manual Scan Button
                    Button(action: {
                        Task {
                            await viewModel.analyzeOnDemand(symbol: symbol)
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                            Text(viewModel.isLoadingNews ? "Taranıyor..." : "Haberleri Şimdi Tara (1 Haftalık)")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isBist ? Color.red.opacity(0.2) : Theme.tint.opacity(0.2))
                        .foregroundColor(isBist ? Color.red : Theme.tint)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoadingNews)
                    .padding(.horizontal)
                    
                    let insights = viewModel.newsInsightsBySymbol[symbol] ?? []
                    if insights.isEmpty {
                        if viewModel.isLoadingNews {
                            HStack {
                                Spacer()
                                ProgressView("Yapay Zeka Analiz Ediyor...")
                                Spacer()
                            }
                            .padding()
                        } else {
                            Text(isBist ? "BIST haberi bulunamadı" : "Haber bulunamadı")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    } else {
                        ForEach(insights) { insight in
                            NewsInsightRow(insight: insight)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(isBist ? "🇹🇷 Hermes BIST" : "Hermes Haberleri")
            .background(Theme.background)
        }
    }
}

struct NewsInsightRow: View {
    let insight: NewsInsight
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.headline)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            Text(insight.summaryTRLong)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            HStack {
                Text(insight.impactSentenceTR)
                    .font(.caption2)
                    .italic()
                    .foregroundColor(Theme.tint)
                
                Spacer()
                
                Text(String(format: "%.0f%% Güven", insight.confidence * 100))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
    }
}
