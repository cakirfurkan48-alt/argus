import SwiftUI
import Charts

struct CrystalWatchlistRow: View {
    let symbol: String
    let quote: Quote?
    let candles: [Candle]?
    
    // Derived
    var changeColor: Color {
        guard let q = quote else { return Theme.textSecondary }
        return q.change >= 0 ? Theme.positive : Theme.negative
    }
    
    // Logo Helper (Duplicated logic from MarketRow, should be centralized but kept here for self-containment)

    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Identity
            HStack(spacing: 12) {
                CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol)
                        .font(.custom("Inter-Bold", size: 15))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(quote?.shortName ?? "Yükleniyor")
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 2. Trend (Sparkline) - "The Heartbeat"
            if let c = candles, c.count >= 10 {
                Chart {
                    ForEach(Array(c.suffix(20).enumerated()), id: \.offset) { index, candle in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Price", candle.close)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(changeColor.gradient)
                    }
                    if let last = c.last {
                        PointMark(
                             x: .value("Time", 19),
                             y: .value("Price", last.close)
                        )
                        .foregroundStyle(changeColor)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 60, height: 30)
                .padding(.horizontal, 4)
            } else {
                // Placeholder line for no data
                Rectangle()
                    .fill(Theme.textSecondary.opacity(0.1))
                    .frame(width: 60, height: 2)
            }
            
            // 3. Data Pill
            if let q = quote {
                let isBist = symbol.uppercased().hasSuffix(".IS")
                let currencySymbol = isBist ? "₺" : "$"
                let priceFormat = "%.2f"
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "\(currencySymbol)\(priceFormat)", q.currentPrice))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(String(format: "%.2f%%", q.percentChange))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(changeColor)
                        .cornerRadius(6)
                }
            } else {
                // Skeleton
                 VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 50, height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 40, height: 14)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Make full row tappable
    }
}
