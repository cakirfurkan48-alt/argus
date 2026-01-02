import Foundation

/// Cronos: The Timing Module of Argus.
/// Analyzes cycles, seasonality, and volatility regimes to determine the "When".
final class CronosTimeEngine: Sendable {
    static let shared = CronosTimeEngine()
    
    private init() {}
    
    /// Calculates the Timing Score (0-100).
    /// Higher Score = Better Time to Enter/Hold Long.
    func calculateTimingScore(candles: [Candle]) -> Double {
        guard !candles.isEmpty else { return 50.0 }
        
        // 1. Seasonality Score (0-100)
        let seasonScore = analyzeSeasonality()
        
        // 2. Cycle Score (Stochastic RSI) (0-100)
        let cycleScore = analyzeCycles(candles: candles)
        
        // 3. Volatility Regime Score (0-100)
        let volatilityScore = analyzeVolatilityRegime(candles: candles)
        
        // Weighted Average
        // Cycle is most important for short-term timing (50%)
        // Seasonality is filter (30%)
        // Volatility is risk adjustment (20%)
        let finalScore = (cycleScore * 0.50) + (seasonScore * 0.30) + (volatilityScore * 0.20)
        
        return finalScore.clamped(to: 0...100)
    }
    
    // MARK: - Sub-Engines
    
    private func analyzeSeasonality() -> Double {
        let date = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.weekday, from: date) // 1=Sun, 2=Mon...
        
        var score = 50.0
        
        // Monthly Seasonality (Simplified "Sell in May" logic)
        // Strong Months: Nov, Dec, Jan, Apr
        // Weak Months: Sep, Jun
        switch month {
        case 11, 12, 1, 4: score += 15 // Santa Rally / Q1 inflows
        case 9, 6: score -= 15         // September effect
        case 5: score -= 10            // Sell in May
        default: break
        }
        
        // Day of Week Effect
        // Turnaround Tuesday (3) often positive
        // Friday (6) often profit taking
        if day == 3 { score += 5 }
        else if day == 6 { score -= 5 }
        
        return score.clamped(to: 20...80)
    }
    
    private func analyzeCycles(candles: [Candle]) -> Double {
        // Use Stochastic RSI as Cycle Proxy
        // If StochRSI is < 20 -> Cycle Bottom (Good Buy Timing) -> High Score
        // If StochRSI is > 80 -> Cycle Top (Bad Buy Timing) -> Low Score
        
        let rsiPeriod = 14
        let stochPeriod = 14
        
        guard candles.count > rsiPeriod + stochPeriod else { return 50.0 }
        
        // 1. Calculate RSI
        let rsiValues = calculateRSIStream(candles: candles, period: rsiPeriod)
        
        // 2. Calculate Stochastic of RSI
        guard rsiValues.count >= stochPeriod else { return 50.0 }
        let currentRSI = rsiValues.last!
        let window = rsiValues.suffix(stochPeriod)
        let minRSI = window.min() ?? 0
        let maxRSI = window.max() ?? 100
        
        let stochRSI = (currentRSI - minRSI) / (maxRSI - minRSI) // 0.0 - 1.0
        
        // Invert Logic for "Buy Timing Score"
        // Key concept:
        // We want to buy at the BOTTOM of the cycle (StochRSI low).
        // So StochRSI 0.0 -> Score 100.
        // StochRSI 1.0 -> Score 0.
        
        return (1.0 - stochRSI) * 100.0
    }
    
    private func analyzeVolatilityRegime(candles: [Candle]) -> Double {
        // Analyze ATR / Price
        let period = 14
        guard candles.count >= period else { return 50.0 }
        
        let atr = calculateATR(candles: candles, period: period)
        let price = candles.last?.close ?? 1.0
        let volatilityPercent = (atr / price) * 100.0
        
        // Logic:
        // Low Vol (< 1.5%) -> Stable Trend -> Score 70
        // Med Vol (1.5% - 3%) -> Score 50
        // High Vol (> 3%) -> Chaotic -> Score 30
        
        if volatilityPercent < 1.5 { return 75.0 }
        else if volatilityPercent < 3.0 { return 50.0 }
        else { return 25.0 }
    }
    
    // MARK: - Helpers
    
    private func calculateRSIStream(candles: [Candle], period: Int) -> [Double] {
        // SSoT: IndicatorService kullanılıyor
        let prices = candles.map { $0.close }
        let rsiArray = IndicatorService.calculateRSI(values: prices, period: period)
        // nil değerleri filtrele ve Double dizisi döndür
        return rsiArray.compactMap { $0 }
    }
    
    private func calculateATR(candles: [Candle], period: Int) -> Double {
        guard candles.count >= period else { return 0.0 }
        
        var trSum = 0.0
        // Simple Average TR for speed (or implement Wilder's if needed)
        let slice = candles.suffix(period)
        for i in 1..<slice.count {
            let current = slice[slice.startIndex + i]
            let prev = slice[slice.startIndex + i - 1]
            
            let tr = max(current.high - current.low, max(abs(current.high - prev.close), abs(current.low - prev.close)))
            trSum += tr
        }
        
        return trSum / Double(period)
    }
}
