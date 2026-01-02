import Foundation

// MARK: - FAZ 3: Service Protocols
// Protocol-based abstraction for testability and DI

/// Market data fetching protocol
protocol MarketDataProviding: Sendable {
    func fetchQuote(symbol: String) async throws -> Quote?
    func fetchCandles(symbol: String, timeframe: String) async throws -> [Candle]
    func searchSymbols(query: String) async throws -> [SearchResult]
}

/// Fundamental data protocol
protocol FundamentalsProviding {
    func getScore(for symbol: String) -> FundamentalScoreResult?
    func calculateScore(data: FinancialsData, riskScore: Double?) -> FundamentalScoreResult?
}

/// Orion technical analysis protocol
protocol OrionAnalyzing {
    func calculateOrionScore(symbol: String, candles: [Candle], spyCandles: [Candle]?) -> OrionScoreResult?
}

// ArgusDeciding, HermesAnalyzing, MacroEvaluating protokolleri
// mevcut servislerin signature'larına tam uyması gerektiğinden
// ileride gerekirse eklenecek. Şimdilik concrete type kullanılıyor.

