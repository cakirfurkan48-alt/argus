import Foundation

// MARK: - Chiron Data Lake Service
/// Centralized storage for Chiron's learning data
actor ChironDataLakeService {
    static let shared = ChironDataLakeService()
    
    // MARK: - Data Paths
    private let basePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ChironDataLake", isDirectory: true)
    }()
    
    init() {
        Task { await setupDirectories() }
    }
    
    private func setupDirectories() {
        let fm = FileManager.default
        let paths = [
            basePath,
            basePath.appendingPathComponent("trades"),
            basePath.appendingPathComponent("module_accuracy"),
            basePath.appendingPathComponent("regime"),
            basePath.appendingPathComponent("learning_logs")
        ]
        
        for path in paths {
            if !fm.fileExists(atPath: path.path) {
                try? fm.createDirectory(at: path, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Trade History
    
    /// Log a completed trade for learning
    func logTrade(_ record: TradeOutcomeRecord) async {
        let path = basePath.appendingPathComponent("trades/\(record.symbol)_history.json")
        var history = await loadTradeHistory(symbol: record.symbol)
        history.append(record)
        
        // Keep last 100 trades per symbol
        if history.count > 100 {
            history = Array(history.suffix(100))
        }
        
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: path)
        } catch {
            print("❌ ChironDataLake: Failed to save trade - \(error)")
        }
    }
    
    func loadTradeHistory(symbol: String) async -> [TradeOutcomeRecord] {
        let path = basePath.appendingPathComponent("trades/\(symbol)_history.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([TradeOutcomeRecord].self, from: data)
        } catch {
            return []
        }
    }
    
    // MARK: - Module Accuracy Tracking
    
    /// Track module prediction accuracy
    func logModulePrediction(_ record: ModulePredictionRecord) async {
        let path = basePath.appendingPathComponent("module_accuracy/\(record.module)_accuracy.json")
        var history = await loadModuleAccuracy(module: record.module)
        history.append(record)
        
        // Keep last 200 predictions per module
        if history.count > 200 {
            history = Array(history.suffix(200))
        }
        
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: path)
        } catch {
            print("❌ ChironDataLake: Failed to save module accuracy - \(error)")
        }
    }
    
    func loadModuleAccuracy(module: String) async -> [ModulePredictionRecord] {
        let path = basePath.appendingPathComponent("module_accuracy/\(module)_accuracy.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([ModulePredictionRecord].self, from: data)
        } catch {
            return []
        }
    }
    
    /// Calculate win rate for a module
    func getModuleWinRate(module: String) async -> Double {
        let history = await loadModuleAccuracy(module: module)
        guard !history.isEmpty else { return 0.5 }
        
        let wins = history.filter { $0.wasCorrect }.count
        return Double(wins) / Double(history.count)
    }
    
    // MARK: - Learning Logs
    
    /// Log a learning event (weight update, rule change, etc.)
    func logLearningEvent(_ event: ChironLearningEvent) async {
        let path = basePath.appendingPathComponent("learning_logs/events.json")
        var events = await loadLearningEvents()
        events.append(event)
        
        // Keep last 50 events
        if events.count > 50 {
            events = Array(events.suffix(50))
        }
        
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: path)
        } catch {
            print("❌ ChironDataLake: Failed to save learning event - \(error)")
        }
    }
    
    func loadLearningEvents() async -> [ChironLearningEvent] {
        let path = basePath.appendingPathComponent("learning_logs/events.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([ChironLearningEvent].self, from: data)
        } catch {
            return []
        }
    }
    
    // MARK: - Summary Statistics
    
    /// Get summary stats for a symbol
    func getSymbolStats(symbol: String) async -> SymbolLearningStats {
        let trades = await loadTradeHistory(symbol: symbol)
        
        let wins = trades.filter { $0.pnlPercent > 0 }.count
        let winRate = trades.isEmpty ? 0 : Double(wins) / Double(trades.count) * 100
        let avgPnl = trades.isEmpty ? 0 : trades.map { $0.pnlPercent }.reduce(0, +) / Double(trades.count)
        
        let corse = trades.filter { $0.engine == .corse }
        let pulse = trades.filter { $0.engine == .pulse }
        
        let corseWinRate = corse.isEmpty ? 0 : Double(corse.filter { $0.pnlPercent > 0 }.count) / Double(corse.count) * 100
        let pulseWinRate = pulse.isEmpty ? 0 : Double(pulse.filter { $0.pnlPercent > 0 }.count) / Double(pulse.count) * 100
        
        return SymbolLearningStats(
            symbol: symbol,
            totalTrades: trades.count,
            winRate: winRate,
            avgPnlPercent: avgPnl,
            corseWinRate: corseWinRate,
            pulseWinRate: pulseWinRate,
            lastUpdated: Date()
        )
    }
}

// MARK: - Data Models

struct TradeOutcomeRecord: Codable, Sendable {
    let id: UUID
    let symbol: String
    let engine: AutoPilotEngine
    let entryDate: Date
    let exitDate: Date
    let entryPrice: Double
    let exitPrice: Double
    let pnlPercent: Double
    let exitReason: String
    
    // Scores at entry time (for learning)
    let orionScoreAtEntry: Double?
    let atlasScoreAtEntry: Double?
    let aetherScoreAtEntry: Double?
    let phoenixScoreAtEntry: Double?
}

struct ModulePredictionRecord: Codable, Sendable {
    let id: UUID
    let module: String  // "orion", "atlas", "phoenix", etc.
    let symbol: String
    let date: Date
    let signal: String  // "BUY", "SELL", "HOLD"
    let scoreAtTime: Double
    let wasCorrect: Bool
    let actualPnl: Double?
}

struct ChironLearningEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let eventType: ChironEventType
    let symbol: String?
    let engine: AutoPilotEngine?
    let description: String
    let reasoning: String
    let confidence: Double
    
    init(id: UUID = UUID(), date: Date = Date(), eventType: ChironEventType, symbol: String? = nil, engine: AutoPilotEngine? = nil, description: String, reasoning: String, confidence: Double) {
        self.id = id
        self.date = date
        self.eventType = eventType
        self.symbol = symbol
        self.engine = engine
        self.description = description
        self.reasoning = reasoning
        self.confidence = confidence
    }
}

enum ChironEventType: String, Codable, Sendable {
    case weightUpdate = "WEIGHT_UPDATE"
    case ruleAdded = "RULE_ADDED"
    case ruleRemoved = "RULE_REMOVED"
    case analysisCompleted = "ANALYSIS_COMPLETED"
    case anomalyDetected = "ANOMALY_DETECTED"
}

struct SymbolLearningStats: Codable, Sendable {
    let symbol: String
    let totalTrades: Int
    let winRate: Double
    let avgPnlPercent: Double
    let corseWinRate: Double
    let pulseWinRate: Double
    let lastUpdated: Date
}
