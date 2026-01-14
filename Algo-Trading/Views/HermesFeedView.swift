import SwiftUI

struct HermesFeedView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var selectedScope = 0 // 0: Takip Listem, 1: Genel Piyasa
    
    // Grid Setup
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var currentInsights: [NewsInsight] {
        return selectedScope == 0 ? viewModel.watchlistNewsInsights : viewModel.generalNewsInsights
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // 1. Selector
                    ScopeSelectorBar(selectedScope: $selectedScope)
                        .padding(.vertical)
                        .onChange(of: selectedScope) { _, newValue in
                            if newValue == 0 && viewModel.watchlistNewsInsights.isEmpty {
                                viewModel.loadWatchlistFeed()
                            } else if newValue == 1 && viewModel.generalNewsInsights.isEmpty {
                                viewModel.loadGeneralFeed()
                            }
                        }
                    
                    if currentInsights.isEmpty {
                         EmptyStateView(
                            scope: selectedScope,
                            isLoading: viewModel.isLoadingNews,
                            errorMessage: viewModel.newsErrorMessage,
                            onRetry: {
                                if selectedScope == 0 { viewModel.loadWatchlistFeed() }
                                else { viewModel.loadGeneralFeed() }
                            }
                         )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                // Section Header for Grid
                                Section(header:
                                    HStack {
                                        Text("Öne Çıkanlar")
                                            .font(.headline)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                ) {
                                    ForEach(currentInsights) { insight in
                                        if insight.symbol != "MARKET" && insight.symbol != "GENERAL" {
                                            NavigationLink(destination: StockDetailView(symbol: insight.symbol, viewModel: viewModel)) {
                                                DiscoveryNewsCard(insight: insight)
                                            }
                                        } else {
                                            DiscoveryNewsCard(insight: insight)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80)
                        }
                        .refreshable {
                            if selectedScope == 0 {
                                viewModel.loadWatchlistFeed()
                            } else {
                                viewModel.loadGeneralFeed()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Keşfet & Haberler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     if viewModel.isLoadingNews {
                         ProgressView()
                     } else {
                         Button(action: {
                             if selectedScope == 0 { viewModel.loadWatchlistFeed() }
                             else { viewModel.loadGeneralFeed() }
                         }) {
                             Image(systemName: "arrow.clockwise")
                         }
                     }
                 }
            }
        }
    }
}

// MARK: - Components

struct ScopeSelectorBar: View {
    @Binding var selectedScope: Int
    
    var body: some View {
        HStack {
            Button(action: { withAnimation { selectedScope = 0 } }) {
                Text("Takip Listem")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(selectedScope == 0 ? Theme.tint : Color.clear)
                    .foregroundColor(selectedScope == 0 ? .white : Theme.textSecondary)
                    .cornerRadius(8)
            }
            
            Button(action: { withAnimation { selectedScope = 1 } }) {
                Text("Genel Piyasa")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(selectedScope == 1 ? Theme.tint : Color.clear)
                    .foregroundColor(selectedScope == 1 ? .white : Theme.textSecondary)
                    .cornerRadius(8)
            }
        }
        .padding(4)
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct DiscoveryNewsCard: View {
    let insight: NewsInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Symbol & Sentiment Badge
            HStack {
                Text(insight.symbol)
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.background)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(4)
                
                Spacer()
                
                // Enhanced Sentiment Badge
                HStack(spacing: 4) {
                    Text(insight.sentiment.displayTitle) // Türkçe Başlık
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(colorForSentiment(insight.sentiment).opacity(0.15))
                .foregroundColor(colorForSentiment(insight.sentiment))
                .cornerRadius(8)
            }
            
            // Headline
            Text(insight.headline)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Impact Comment (Detay)
            // Kullanıcı bu detayı istedi
            if !insight.impactSentenceTR.isEmpty {
                Text(insight.impactSentenceTR)
                    .font(.caption)
                    .italic()
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            
            Spacer(minLength: 0)
            
            // Footer: Time & Viral
            HStack {
                Text(timeAgo(insight.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if HermesHypeEngine.shared.isViral(symbol: insight.symbol) {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                        Text("Viral")
                    }
                    .font(.caption2)
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(12)
        .frame(minHeight: 160) // Kart yüksekliği biraz artırıldı
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func colorForSentiment(_ s: NewsSentiment) -> Color {
        switch s {
        case .strongPositive: return Theme.positive
        case .weakPositive: return Theme.positive.opacity(0.7)
        case .neutral: return .gray
        case .weakNegative: return Theme.negative.opacity(0.7)
        case .strongNegative: return Theme.negative
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyStateView: View {
    let scope: Int
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle().fill(Theme.secondaryBackground).frame(width: 120, height: 120)
                ArgusEyeView(mode: .hermes, size: 80)
            }
            
            VStack(spacing: 8) {
                Text(scope == 0 ? "Takip Listesi Taranıyor" : "Piyasa Taranıyor")
                    .font(.title3)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
                
                Text(isLoading ? "Hermes yapay zekası haberleri analiz ediyor..." : "Veri bulunamadı veya henüz analiz yapılmadı.")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let error = errorMessage {
                 Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if !isLoading {
                Button(action: onRetry) {
                    Text("Analizi Başlat")
                        .bold()
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Theme.tint)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }
            
            Spacer()
        }
    }
}

