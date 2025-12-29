import Foundation

// MARK: - AI Signal Models

struct AISignal: Identifiable, Codable {
    var id = UUID()
    let symbol: String
    let action: SignalAction // BUY, SELL, HOLD
    let confidenceScore: Double // 0-100
    let strategyName: String
    let reason: String
    let timestamp: Date
}

// MARK: - AI Signal Provider Protocol

protocol AISignalProvider {
    func generateSignals(quotes: [String: Quote], candles: [String: [Candle]]) async -> [AISignal]
}

// MARK: - AI Signal Service (Implementation)

class AISignalService: AISignalProvider {
    static let shared = AISignalService()
    
    private init() {}
    
    /// Generates AI-driven signals based on REAL market data and strategies.
    ///
    /// - Parameters:
    ///   - quotes: Current market quotes.
    ///   - candles: Historical candle data.
    /// - Returns: A list of `AISignal` objects.
    func generateSignals(quotes: [String: Quote], candles: [String: [Candle]]) async -> [AISignal] {
        var signals: [AISignal] = []
        
        // Her sembol için stratejileri çalıştır
        for (symbol, symbolCandles) in candles {
            // Yeterli veri yoksa atla
            guard symbolCandles.count > 50 else { continue }
            
            // Backtest motorunu çalıştır (Gerçek hesaplama)
            let results = await BacktestEngine.shared.runAllStrategies(candles: symbolCandles)
            
            // En iyi stratejileri filtrele
            // Kriter: Skoru yüksek (>70) VE şu anki aksiyonu BUY veya SELL olanlar
            let actionableStrategies = results.filter { result in
                result.score >= 70 && (result.currentAction == .buy || result.currentAction == .sell)
            }
            
            // En yüksek skorlu stratejiyi seç (Sinyal kirliliğini önlemek için sembol başına 1 sinyal)
            if let bestStrategy = actionableStrategies.max(by: { $0.score < $1.score }) {
                
                let reason = generateReason(strategy: bestStrategy)
                
                let signal = AISignal(
                    symbol: symbol,
                    action: bestStrategy.currentAction,
                    confidenceScore: bestStrategy.score,
                    strategyName: bestStrategy.strategyName,
                    reason: reason,
                    timestamp: Date()
                )
                signals.append(signal)
            }
        }
        
        // Güven skoruna göre sırala (En yüksek en üstte)
        return signals.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    private func generateReason(strategy: StrategyResult) -> String {
        let actionText = strategy.currentAction == .buy ? "AL" : "SAT"
        return "\(strategy.strategyName) stratejisi, %\(String(format: "%.1f", strategy.winRate)) kazanma oranı ve %\(String(format: "%.1f", strategy.totalReturn)) geçmiş getiri ile \(actionText) sinyali üretti."
    }
}
