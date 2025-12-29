import Foundation

// MARK: - Backtest Engine
// Verilen mum verileri üzerinde tüm stratejileri çalıştırır ve sıralar.

class BacktestEngine {
    static let shared = BacktestEngine()
    
    static let strategies: [Strategy] = [
        OrionStrategy(), // The Brain (New)
        RSIStrategy(),
        MACDStrategy(),
        SMACrossoverStrategy(),
        BollingerStrategy(),
        StochasticStrategy(),
        CCIStrategy()
    ]
    
    private init() {}
    
    func runAllStrategies(candles: [Candle]) async -> [StrategyResult] {
        // Capture strategies
        let strats = BacktestEngine.strategies
        
        // Run in a detached task to avoid blocking calling thread
        return await Task.detached(priority: .userInitiated) {
            var results: [StrategyResult] = []
            
            for strategy in strats {
                // Assume strategies are pure calculations
                let result = await Task { @MainActor in 
                     // Temporary fix: If strategy is main actor isolated, run it there. 
                     // Ideally strategies should be nonisolated.
                     return strategy.backtest(candles: candles)
                }.value
                results.append(result)
            }
            
            // Skora göre sırala (En yüksek skor en üstte)
            return results.sorted { $0.score > $1.score }
        }.value
    }
}
