import SwiftUI

struct OrionDetailView: View {
    let symbol: String
    let orion: OrionScoreResult
    let candles: [Candle]?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 0. Backtest Card (NEW)
                if let candles = candles, !candles.isEmpty {
                    NavigationLink(destination: OrionBacktestView(symbol: symbol, candles: candles)) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Geçmiş Test")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Orion skoruyla backtest simülasyonu")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }
                
                // 1. Header Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 6) {
                                Text("ORION 3.0")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(symbol.uppercased().hasSuffix(".IS") ? .red : .purple)
                                
                                // BIST Badge
                                if symbol.uppercased().hasSuffix(".IS") {
                                    Text("🇹🇷 BIST")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.8))
                                        .cornerRadius(4)
                                }
                            }
                            Text("Teknik Puan")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(colorForScore(orion.score).opacity(0.3), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            Text("\(Int(orion.score))")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundColor(colorForScore(orion.score))
                        }
                    }
                    
                    Divider()
                    
                    Text(symbol.uppercased().hasSuffix(".IS") ? "Orion teknik motoru BIST hissesini analiz eder. Türk Lirası bazlı fiyat ve hacim verileri kullanılır." : "Orion teknik motoru hisseyi analiz eder. Konsey kararı için aşağıdaki 'Konsey Kararı' bölümüne bakın.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Theme.secondaryBackground)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // 2. Components Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Orion V2 Mimarisi")
                        .font(.headline)
                        .padding(.leading)
                    
                    // 1. Structure (35p) - NEW
                    LegCard(
                        title: "Piyasa Yapısı (Structure)",
                        score: orion.components.structure,
                        maxScore: 35,
                        desc: orion.components.structureDesc,
                        icon: "building.columns.fill" // Map/Structure
                    )
                    
                    // 2. Trend (25p)
                    LegCard(
                        title: "Trend & Akış",
                        score: orion.components.trend,
                        maxScore: 25,
                        desc: orion.components.trendDesc,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                    
                    // 3. Momentum (25p)
                    LegCard(
                        title: "Momentum",
                        score: orion.components.momentum,
                        maxScore: 25,
                        desc: orion.components.momentumDesc,
                        icon: "speedometer"
                    )
                    
                    // 4. Pattern (15p) - NEW
                    LegCard(
                        title: "Formasyonlar (Pattern)",
                        score: orion.components.pattern,
                        maxScore: 15,
                        desc: orion.components.patternDesc,
                        icon: "eye.fill" // Observation
                    )
                }
                .padding(.horizontal)
                
                // 3. ORION COUNCIL CARD (NEW!)
                if let candles = candles, candles.count >= 50 {
                    OrionCouncilCard(symbol: symbol, candles: candles)
                }
            }
            .padding(.vertical)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Orion Teknik")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func colorForScore(_ score: Double) -> Color {
        if score >= 70 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

struct LegCard: View {
    let title: String
    let score: Double
    let maxScore: Double
    let desc: String
    let icon: String
    
    var progress: Double {
        score / maxScore
    }
    
    var scoreColor: Color {
        progress > 0.7 ? .green : (progress > 0.4 ? .yellow : .red)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.background)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(Theme.tint)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text("\(Int(score)) / \(Int(maxScore))")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(scoreColor)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        Capsule()
                            .fill(scoreColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 6)
                    }
                }
                .frame(height: 6)
                
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
}
