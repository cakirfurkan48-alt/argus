import SwiftUI

struct SirkiyeDashboardView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var rotateOrbit = false
    @State private var showDetails = false
    
    // Derived from ViewModel or Mock for now if not computed globally
    // Ideally this should come from SirkiyeEngine via ViewModel
    var atmosphere: (score: Double, mode: MarketMode, reason: String) {
        // Quick fallback or get from ViewModel if implemented
        // For now, assume neutral if no data, but we want it to be real.
        // We will assume ViewModel exposes a 'bistAtmosphere' or similar later.
        // For now, we visualize a placeholder that invites the user to tap for details.
        return (55.0, .neutral, "Analiz Bekleniyor")
    }
    
    var body: some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: 0) {
                // Left: Cortex Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [.cyan, .purple, .red]), center: .center),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(rotateOrbit ? 360 : 0))
                        .animation(Animation.linear(duration: 8).repeatForever(autoreverses: false), value: rotateOrbit)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan)
                }
                .padding(.leading, 16)
                .padding(.vertical, 16)
                
                // Center: Text Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("SİRKİYE KORTEKS")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Text("Politik Atmosfer")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Veri Akışı Aktif")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 12)
                
                Spacer()
                
                // Right: Value/Action
                VStack(alignment: .trailing) {
                    Text("BIST 100")
                        .font(.caption).bold().foregroundColor(.secondary)
                    
                    Text("RİSK ANALİZİ")
                        .font(.caption2).bold()
                        .paddingbadge(Color.purple)
                }
                .padding(.trailing, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.secondaryBackground)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
        }
        .onAppear { rotateOrbit = true }
        .sheet(isPresented: $showDetails) {
            SirkiyeDetailsSheet(viewModel: viewModel)
        }
    }
}

// Custom Badge Helper
extension View {
    func paddingbadge(_ color: Color) -> some View {
        self.padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// Sheet for Detailed View (News + Scores)
struct SirkiyeDetailsSheet: View {
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Optional: If nil, shows "General/Market" news. If set, shows symbol news.
    var symbol: String?
    
    var newsInsights: [NewsInsight] {
        if let s = symbol, let list = viewModel.newsInsightsBySymbol[s] {
            return list
        } else {
            // General Dashboard Mode: Use 'generalNewsInsights' from ViewModel
            // Or aggregate BIST specific news if available
            return viewModel.generalNewsInsights
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Pulse
                        ZStack {
                            Circle().fill(Color.purple.opacity(0.1)).frame(width: 120, height: 120)
                            Circle().stroke(Color.purple.opacity(0.5), lineWidth: 1).frame(width: 140, height: 140)
                            Image(systemName: "eye.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.purple)
                        }
                        .padding(.top, 20)
                        
                        Text("SİRKİYE GÖZETİMİ")
                            .font(.title2).bold().foregroundColor(.white).tracking(2)
                        
                        if let s = symbol {
                            Text("\(s) için politik ve sistemik risk takibi.")
                                .font(.caption).foregroundColor(.gray)
                        } else {
                            Text("Borsa İstanbul Genel Atmosfer")
                                .font(.caption).foregroundColor(.gray)
                        }
                        
                        // Score Cards
                        HStack(spacing: 16) {
                            ScoreCard(title: "POLİTİK", value: "NÖTR", color: .yellow, icon: "building.columns.fill")
                            ScoreCard(title: "JEOPOLİTİK", value: "SAKİN", color: .green, icon: "globe.europe.africa.fill")
                        }
                        .padding(.horizontal)
                        
                        // News Feed Placeholder
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("KRİTİK BAŞLIKLAR").font(.caption).bold().foregroundColor(.gray)
                                Spacer()
                                if viewModel.isLoadingNews {
                                    ProgressView().scaleEffect(0.7)
                                } else {
                                    Button(action: { refreshNews() }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                            
                            if newsInsights.isEmpty {
                                Text(viewModel.isLoadingNews ? "Veri çekiliyor..." : "Henüz kritik bir başlık tespit edilmedi.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(newsInsights, id: \.id) { insight in
                                    NewsRow(
                                        source: insight.symbol == "GENERAL" ? "Piyasa" : insight.symbol,
                                        title: insight.headline,
                                        time: timeAgo(insight.createdAt),
                                        sentiment: insight.sentiment
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarItems(trailing: Button("Kapat") { presentationMode.wrappedValue.dismiss() })
            .onAppear {
                if newsInsights.isEmpty {
                    refreshNews()
                }
            }
        }
    }
    
    private func refreshNews() {
        if let s = symbol {
            viewModel.loadNewsAndInsights(for: s, isGeneral: false)
        } else {
            viewModel.loadGeneralFeed()
        }
    }
    
    // Helper
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ScoreCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2).bold().foregroundColor(.gray)
            
            Text(value)
                .font(.headline).bold().foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct NewsRow: View {
    let source: String
    let title: String
    let time: String
    var sentiment: NewsSentiment = .neutral // Add sentiment color
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(sentimentColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(source).font(.caption2).bold().foregroundColor(.gray)
                    Spacer()
                    Text(time).font(.caption2).foregroundColor(.gray)
                }
                Text(title).font(.subheadline).foregroundColor(.white).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    var sentimentColor: Color {
        switch sentiment {
        case .strongPositive, .weakPositive: return .green
        case .strongNegative, .weakNegative: return .red
        default: return .purple
        }
    }
}
