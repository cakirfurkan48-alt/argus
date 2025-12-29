import Foundation

// MARK: - Auto-Pilot Service
/// The Engine for Automated Trading (Paper Mode).
/// STRICTLY uses REAL Data. NO Simulations.
final class AutoPilotService: Sendable {
    static let shared = AutoPilotService()
    
    // State
    private let tradeHistoryKey = "Argus_PaperTrades_v1"
    private var isScanning = false
    
    // Dependencies
    private let market = MarketDataProvider.shared
    private let analysis = OrionAnalysisService.shared
    private let cache = HermesCacheStore.shared // For news context if needed later
    
    private init() {}
    
    // MARK: - Public API
    
    /// Scans the provided list of symbols for high-conviction setups.
    /// Returns a list of Signals. Execution happens in ViewModel.
    func scanMarket(symbols: [String], equity: Double, buyingPower: Double, portfolio: [String: Trade]) async -> (signals: [TradeSignal], logs: [ScoutLog]) {
        guard !isScanning else { return ([], []) }
        isScanning = true
        defer { isScanning = false }
        
        var signals: [TradeSignal] = []
        var logs: [ScoutLog] = []
        
        // Ensure Aether Freshness
        var aether = MacroRegimeService.shared.getCachedRating()
        if aether == nil {
            print("⏳ Auto-Pilot: Aether data stale. Refreshing Macro Environment...")
            aether = await MacroRegimeService.shared.computeMacroEnvironment()
        }
        
        if await HeimdallOrchestrator.shared.checkSystemHealth() == .critical {
            print("🛑 Auto-Pilot: System Health Critical. Aborting Scan.")
            return ([], [])
        }
        
        print("🤖 Auto-Pilot: Argus Engine Scanning \(symbols.count) symbols (Regime: \(aether?.regime.displayName ?? "Unknown"))...")
        
        for symbol in symbols {
            do {
                // 1. Fetch Data
                // Priority: Realtime Quote > Candle Close
                var currentPrice: Double = 0.0
                
                // Fetch Candles for Analysis (Orion needs history)
                let candles = try? await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 200)
                guard let lastCandle = candles?.last else { 
                    logs.append(ScoutLog(symbol: symbol, status: "RED", reason: "Mum Verisi Yok (Heimdall)", score: 0))
                    continue 
                }
                
                // Fetch Realtime Price for Execution Accuracy
                if let quote = try? await HeimdallOrchestrator.shared.requestQuote(symbol: symbol) {
                    currentPrice = quote.currentPrice
                } else {
                    currentPrice = lastCandle.close // Fallback
                    print("⚠️ Auto-Pilot: Using Candle Close for \(symbol) (Heimdall Quote Failed)")
                }
                
                // 2. Scores
                let orion = analysis.calculateOrionScore(symbol: symbol, candles: candles ?? [], spyCandles: nil)
                let atlas = FundamentalScoreStore.shared.getScore(for: symbol)
                // Default Cronos to 50 (Neutral) if not available
                
                // 3. Evaluate via Argus Engine
                let decision = await ArgusAutoPilotEngine.shared.evaluate(
                    symbol: symbol,
                    currentPrice: currentPrice,
                    equity: equity,
                    buyingPower: buyingPower,
                    portfolioState: portfolio,
                    candles: candles,
                    atlasScore: atlas?.totalScore,
                    orionScore: orion?.score,
                    orionDetails: orion?.components,
                    aetherRating: aether,
                    hermesInsight: nil, // Skipping News for speed/cost in loop
                    argusFinalScore: nil, 
                    cronosScore: 50.0 
                )
                
                // Capture Log
                logs.append(decision.log)
                
                // 4. Map to TradeSignal
                if let sig = decision.signal {
                    // Accept BUY and SELL signals
                    let signal = TradeSignal(
                        symbol: symbol,
                        action: sig.action,
                        reason: sig.reason,
                        confidence: 80.0,
                        timestamp: Date(),
                        stopLoss: sig.stopLoss,
                        takeProfit: sig.takeProfit,
                        trimPercentage: sig.trimPercentage
                    )
                    signals.append(signal)
                    print("✅ Argus Signal: \(symbol) -> \(sig.action.rawValue.uppercased())")
                }
            }
        }
        
        return (signals, logs)
    }
}
