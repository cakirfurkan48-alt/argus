import SwiftUI

struct ArgusBistHub: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("BIST INTELLIGENCE")
                        .font(.custom("Menlo-Bold", size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal)
                
                // 1. Sirkiye Makro Kokpit (Enflasyon, Faiz, USD)
                SirkiyeMacroCockpit(viewModel: viewModel)
                
                // 2. Yabancı Takas (Smart Money)
                if let flow = viewModel.foreignFlowData[symbol] {
                    ForeignFlowSentinel(flow: flow)
                } else {
                    ForeignFlowSentinel(flow: nil) // Empty State
                }
                
                // 3. Hibrit Puanlama (Argus Fusion)
                FusionScoreCard(symbol: symbol, viewModel: viewModel)
                
                // 4. KAP Bildirimleri
                if let kaps = viewModel.kapDisclosures[symbol], !kaps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KAP BİLDİRİMLERİ")
                            .font(.custom("Menlo-Bold", size: 12))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        ForEach(kaps.prefix(3)) { news in // İlk 3 bildirim
                            KAPDisclosureRow(news: news)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemBackground)) // Theme uyumlu
    }
}

// MARK: - 1. Sirkiye Macro Cockpit
struct SirkiyeMacroCockpit: View {
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MAKRO RÜZGAR (SIRKIYE)")
                .font(.custom("Menlo-Bold", size: 12))
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Enflasyon Kartı
                MacroCard(
                    title: "ENFLASYON",
                    value: String(format: "%%%.1f", viewModel.tcmbData?.inflation ?? 0),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .red
                )
                
                // Faiz Kartı
                MacroCard(
                    title: "FAİZ",
                    value: String(format: "%%%.0f", viewModel.tcmbData?.policyRate ?? 0),
                    icon: "building.columns.fill",
                    color: .blue
                )
                
                // Reel Getiri
                let inf = viewModel.tcmbData?.inflation ?? 0
                let rate = viewModel.tcmbData?.policyRate ?? 0
                let real = rate - inf
                
                MacroCard(
                    title: "REEL FAİZ",
                    value:String(format: "%%%.1f", real),
                    icon: real > 0 ? "plus.circle.fill" : "minus.circle.fill",
                    color: real > 0 ? .green : .red,
                    isHighlight: true
                )
            }
            .padding(.horizontal)
        }
    }
}

struct MacroCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isHighlight: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.custom("Menlo", size: 10))
            }
            .foregroundColor(.gray)
            
            Text(value)
                .font(.custom("Menlo-Bold", size: 16))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlight ? color.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - 2. Foreign Flow Sentinel
struct ForeignFlowSentinel: View {
    let flow: ForeignInvestorFlowService.ForeignFlowData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YABANCI TAKAS (SENTINEL)")
                    .font(.custom("Menlo-Bold", size: 12))
                    .foregroundColor(.gray)
                Spacer()
                if let f = flow {
                    Text(f.timestamp.formatted(date: .numeric, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4))
                
                if let f = flow {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(f.trend.rawValue)
                                .font(.custom("Menlo-Bold", size: 18))
                                .foregroundColor(colorForTrend(f.trend))
                            
                            Text("Yabancı Payı: %\(String(format: "%.2f", f.foreignRatio))")
                                .font(.custom("Menlo", size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Bar Visualization
                        VStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Rectangle()
                                    .fill(barColor(for: i, trend: f.trend))
                                    .frame(width: 30, height: 6)
                                    .cornerRadius(2)
                            }
                        }
                    }
                    .padding()
                } else {
                    Text("Veri bekleniyor...")
                        .font(.custom("Menlo", size: 12))
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .frame(height: 80)
            .padding(.horizontal)
        }
    }
    
    func colorForTrend(_ trend: ForeignInvestorFlowService.FlowTrend) -> Color {
        switch trend {
        case .strongBuy, .buy: return .green
        case .neutral: return .yellow
        case .sell, .strongSell: return .red
        }
    }
    
    func barColor(for index: Int, trend: ForeignInvestorFlowService.FlowTrend) -> Color {
        let activeColor = colorForTrend(trend)
        let intensity: Int
        
        switch trend {
        case .strongBuy: intensity = 5
        case .buy: intensity = 3
        case .neutral: intensity = 1
        case .sell: intensity = 3
        case .strongSell: intensity = 5
        }
        
        // Alttan yukarı (5-i)
        return (5 - index) <= intensity ? activeColor : activeColor.opacity(0.2)
    }
}

// MARK: - 3. Fusion Score Card
struct FusionScoreCard: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    var orionScore: Double { viewModel.orionScores[symbol]?.score ?? 0 }
    var atlasScore: Double { viewModel.getFundamentalScore(for: symbol)?.totalScore ?? 0 }
    var hermesScore: Double { viewModel.newsInsightsBySymbol[symbol]?.first?.impactScore ?? 50 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HİBRİT ANALİZ (ARGUS FUSION)")
                    .font(.custom("Menlo-Bold", size: 12))
                    .foregroundColor(.gray)
                Spacer()
                
                // Final Score Badge
                let finalScore = (orionScore * 0.4) + (atlasScore * 0.4) + (hermesScore * 0.2)
                Text(String(format: "%.0f", finalScore))
                    .font(.custom("Menlo-Bold", size: 24))
                    .foregroundColor(Color.cyan)
                    .padding(8)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.horizontal)
            
            HStack(spacing: 0) {
                FusionComponent(label: "TEKNİK", score: orionScore, weight: "40%", color: .blue)
                FusionComponent(label: "TEMEL", score: atlasScore, weight: "40%", color: .purple)
                FusionComponent(label: "HABER", score: hermesScore, weight: "20%", color: .orange)
            }
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct FusionComponent: View {
    let label: String
    let score: Double
    let weight: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.custom("Menlo-Bold", size: 10))
                .foregroundColor(color)
            
            Text(String(format: "%.0f", score))
                .font(.custom("Menlo", size: 16))
                .foregroundColor(.white)
            
            Text(weight)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(.gray.opacity(0.2)),
            alignment: .trailing
        )
    }
}
