import Foundation

// MARK: - Chiron Learning Job
/// Periodic learning cycle that analyzes performance and updates weights
@MainActor
final class ChironLearningJob {
    static let shared = ChironLearningJob()
    
    private let dataLake = ChironDataLakeService.shared
    private let weightStore = ChironWeightStore.shared
    
    private var lastAnalysisDate: Date?
    private var isRunning = false
    
    private init() {}
    
    // MARK: - Public API
    
    /// Trigger a learning analysis for a specific symbol
    func analyzeSymbol(_ symbol: String) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        
        print("🧠 Chiron Learning: Analyzing \(symbol)...")
        
        // 1. Load trade history
        let trades = await dataLake.loadTradeHistory(symbol: symbol)
        guard trades.count >= 5 else {
            print("⏳ Not enough trades for \(symbol) (min 5)")
            return
        }
        
        // 2. Analyze performance by engine
        let corseTrades = trades.filter { $0.engine == .corse }
        let pulseTrades = trades.filter { $0.engine == .pulse }
        let corseAnalysis = analyzeEngine(trades: corseTrades)
        let pulseAnalysis = analyzeEngine(trades: pulseTrades)
        
        // 3. Generate weight recommendations (LLM for 10+ trades, deterministic otherwise)
        if corseTrades.count >= 10 {
            // Use LLM for intelligent analysis
            let currentCorse = weightStore.getWeights(symbol: symbol, engine: .corse)
            if let llmWeights = await ChironLLMAdapter.shared.recommendWeights(
                symbol: symbol,
                engine: .corse,
                tradeHistory: corseTrades,
                currentWeights: currentCorse
            ) {
                weightStore.updateWeights(symbol: symbol, engine: .corse, weights: llmWeights)
                await logLearningEvent(symbol: symbol, engine: .corse, weights: llmWeights)
                print("🤖 Chiron: LLM weight recommendation applied for \(symbol) CORSE")
            }
        } else if let corseWeights = generateWeightRecommendation(symbol: symbol, engine: .corse, analysis: corseAnalysis) {
            weightStore.updateWeights(symbol: symbol, engine: .corse, weights: corseWeights)
            await logLearningEvent(symbol: symbol, engine: .corse, weights: corseWeights)
        }
        
        if pulseTrades.count >= 10 {
            // Use LLM for intelligent analysis
            let currentPulse = weightStore.getWeights(symbol: symbol, engine: .pulse)
            if let llmWeights = await ChironLLMAdapter.shared.recommendWeights(
                symbol: symbol,
                engine: .pulse,
                tradeHistory: pulseTrades,
                currentWeights: currentPulse
            ) {
                weightStore.updateWeights(symbol: symbol, engine: .pulse, weights: llmWeights)
                await logLearningEvent(symbol: symbol, engine: .pulse, weights: llmWeights)
                print("🤖 Chiron: LLM weight recommendation applied for \(symbol) PULSE")
            }
        } else if let pulseWeights = generateWeightRecommendation(symbol: symbol, engine: .pulse, analysis: pulseAnalysis) {
            weightStore.updateWeights(symbol: symbol, engine: .pulse, weights: pulseWeights)
            await logLearningEvent(symbol: symbol, engine: .pulse, weights: pulseWeights)
        }
        
        lastAnalysisDate = Date()
        print("✅ Chiron Learning: \(symbol) analysis complete")
    }
    
    /// Run full analysis on all symbols with trade history
    func runFullAnalysis() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        
        print("🧠 Chiron Learning: Starting full analysis...")
        
        // Get all symbols with trade history
        let fm = FileManager.default
        let tradesPath = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ChironDataLake/trades")
        
        guard let files = try? fm.contentsOfDirectory(at: tradesPath, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            let symbol = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_history", with: "")
            await analyzeSymbol(symbol)
        }
        
        lastAnalysisDate = Date()
        print("✅ Chiron Learning: Full analysis complete")
    }
    
    // MARK: - Analysis Logic
    
    private struct EngineAnalysis {
        let tradeCount: Int
        let winRate: Double
        let avgPnl: Double
        let modulePerformance: [String: Double] // module -> correlation with wins
    }
    
    private func analyzeEngine(trades: [TradeOutcomeRecord]) -> EngineAnalysis {
        guard !trades.isEmpty else {
            return EngineAnalysis(tradeCount: 0, winRate: 0, avgPnl: 0, modulePerformance: [:])
        }
        
        let wins = trades.filter { $0.pnlPercent > 0 }
        let winRate = Double(wins.count) / Double(trades.count)
        let avgPnl = trades.map { $0.pnlPercent }.reduce(0, +) / Double(trades.count)
        
        // Calculate module correlations with wins
        var modulePerformance: [String: Double] = [:]
        
        // Orion correlation
        let orionWins = wins.compactMap { $0.orionScoreAtEntry }
        let orionLosses = trades.filter { $0.pnlPercent <= 0 }.compactMap { $0.orionScoreAtEntry }
        if !orionWins.isEmpty && !orionLosses.isEmpty {
            let avgOrionWin = orionWins.reduce(0, +) / Double(orionWins.count)
            let avgOrionLoss = orionLosses.reduce(0, +) / Double(orionLosses.count)
            modulePerformance["orion"] = avgOrionWin - avgOrionLoss // Higher = better predictor
        }
        
        // Atlas correlation
        let atlasWins = wins.compactMap { $0.atlasScoreAtEntry }
        let atlasLosses = trades.filter { $0.pnlPercent <= 0 }.compactMap { $0.atlasScoreAtEntry }
        if !atlasWins.isEmpty && !atlasLosses.isEmpty {
            let avgAtlasWin = atlasWins.reduce(0, +) / Double(atlasWins.count)
            let avgAtlasLoss = atlasLosses.reduce(0, +) / Double(atlasLosses.count)
            modulePerformance["atlas"] = avgAtlasWin - avgAtlasLoss
        }
        
        // Phoenix correlation
        let phoenixWins = wins.compactMap { $0.phoenixScoreAtEntry }
        let phoenixLosses = trades.filter { $0.pnlPercent <= 0 }.compactMap { $0.phoenixScoreAtEntry }
        if !phoenixWins.isEmpty && !phoenixLosses.isEmpty {
            let avgPhoenixWin = phoenixWins.reduce(0, +) / Double(phoenixWins.count)
            let avgPhoenixLoss = phoenixLosses.reduce(0, +) / Double(phoenixLosses.count)
            modulePerformance["phoenix"] = avgPhoenixWin - avgPhoenixLoss
        }
        
        return EngineAnalysis(
            tradeCount: trades.count,
            winRate: winRate,
            avgPnl: avgPnl,
            modulePerformance: modulePerformance
        )
    }
    
    private func generateWeightRecommendation(
        symbol: String,
        engine: AutoPilotEngine,
        analysis: EngineAnalysis
    ) -> ChironModuleWeights? {
        guard analysis.tradeCount >= 5 else { return nil }
        
        // Get current weights as baseline
        let current = weightStore.getWeights(symbol: symbol, engine: engine)
        
        // Adjust weights based on module performance
        var orion = current.orion
        var atlas = current.atlas
        var phoenix = current.phoenix
        var aether = current.aether
        let hermes = current.hermes
        let cronos = current.cronos
        
        // Increase weight for modules that correlate with wins
        let learningRate = 0.1 // Conservative adjustment
        
        if let orionDelta = analysis.modulePerformance["orion"] {
            orion += learningRate * (orionDelta > 0 ? 0.05 : -0.03)
        }
        
        if let atlasDelta = analysis.modulePerformance["atlas"] {
            atlas += learningRate * (atlasDelta > 0 ? 0.05 : -0.03)
        }
        
        if let phoenixDelta = analysis.modulePerformance["phoenix"] {
            phoenix += learningRate * (phoenixDelta > 0 ? 0.05 : -0.03)
        }
        
        // Adjust aether based on overall win rate
        if analysis.winRate < 0.4 {
            aether += 0.05 // More macro awareness when losing
        }
        
        // Clamp weights to reasonable bounds
        orion = max(0.1, min(0.5, orion))
        atlas = max(0.1, min(0.5, atlas))
        phoenix = max(0.05, min(0.4, phoenix))
        aether = max(0.05, min(0.3, aether))
        
        let reasoning = """
        Analiz: \(analysis.tradeCount) trade, WinRate: \(Int(analysis.winRate * 100))%, AvgPnL: \(String(format: "%.1f", analysis.avgPnl))%
        Modül performansı: Orion=\(analysis.modulePerformance["orion"] ?? 0), Atlas=\(analysis.modulePerformance["atlas"] ?? 0)
        """
        
        return ChironModuleWeights(
            orion: orion,
            atlas: atlas,
            phoenix: phoenix,
            aether: aether,
            hermes: hermes,
            cronos: cronos,
            updatedAt: Date(),
            confidence: min(0.9, 0.5 + Double(analysis.tradeCount) * 0.02),
            reasoning: reasoning
        )
    }
    
    private func logLearningEvent(symbol: String, engine: AutoPilotEngine, weights: ChironModuleWeights) async {
        let event = ChironLearningEvent(
            eventType: .weightUpdate,
            symbol: symbol,
            engine: engine,
            description: "Ağırlık güncellendi: O:\(Int(weights.orion*100))% A:\(Int(weights.atlas*100))% P:\(Int(weights.phoenix*100))%",
            reasoning: weights.reasoning,
            confidence: weights.confidence
        )
        await dataLake.logLearningEvent(event)
    }
}
