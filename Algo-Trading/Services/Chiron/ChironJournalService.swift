import Foundation

// MARK: - Chiron Journal Models

/// A complete record of a "Council Debate" and its outcome.
/// Used by Chiron to learn which modules are reliable.
struct ChironDecisionLog: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let symbol: String
    
    // Context
    let marketPrice: Double
    let regime: String? // "Bull", "Bear", "Sideways"
    
    // The Council's Config
    let opinions: [String: ModuleOpinionSnapshot] // ModuleName -> Opinion
    
    // The Decision
    let proposedAction: String // Leader's motion
    let finalAction: String    // Final outcome
    let tier: String           // "Tier 1", "Tier 2", etc.
    let consensusScore: Double
    let consensusQuality: Double
    
    // The Outcome (To be filled later)
    var resultT15: PriceOutcome? // After 15 mins
    var resultT60: PriceOutcome? // After 1 hour
}

struct ModuleOpinionSnapshot: Codable, Sendable {
    let stance: String // SUPPORT, OBJECT, CLAIM
    let score: Double
    let confidence: Double
}

struct PriceOutcome: Codable, Sendable {
    let price: Double
    let changePercent: Double
    let isSuccess: Bool // Did it move in favor?
}

// MARK: - Chiron Journal Service

/// The Memory Bank of Argus. Stores decisions and checks them against future price action.
actor ChironJournalService {
    static let shared = ChironJournalService()
    
    // In-Memory Storage (Prototoype Phase)
    // TODO: Persist to SwiftData or SQLite
    private var logs: [ChironDecisionLog] = []
    
    private init() {}
    
    /// Log a new decision from Argus Engine
    func logDecision(
        trace: AgoraTrace,
        opinions: [ModuleOpinion],
        marketPrice: Double,
        tier: String,
        quality: Double
    ) {
        // Map opinions to snapshot
        var opinionMap: [String: ModuleOpinionSnapshot] = [:]
        for op in opinions {
            opinionMap[op.module.rawValue] = ModuleOpinionSnapshot(
                stance: op.stance.rawValue,
                score: op.score,
                confidence: op.confidence
            )
        }
        
        let log = ChironDecisionLog(
            id: trace.id,
            timestamp: trace.timestamp,
            symbol: trace.symbol,
            marketPrice: marketPrice,
            regime: nil, // TODO: Fetch from Aether
            opinions: opinionMap,
            proposedAction: trace.debate.claimant?.preferredAction.rawValue ?? "HOLD",
            finalAction: trace.finalDecision.action.rawValue,
            tier: tier,
            consensusScore: trace.debate.consensusParams.netScore,
            consensusQuality: quality,
            resultT15: nil,
            resultT60: nil
        )
        
        logs.append(log)
        print("📝 Chiron Journal: Logged decision for \(trace.symbol) (Tier: \(tier))")
    }
    
    /// Returns all logs for visualization/analysis
    func getLogs() -> [ChironDecisionLog] {
        return logs
    }
    
    /// Logs processing results (TBD: Run periodically)
    func updateOutcomes(currentPrices: [String: Double]) {
        let now = Date()
        
        for i in 0..<logs.count {
            var log = logs[i]
            guard let currentPrice = currentPrices[log.symbol] else { continue }
            
            // Check T+15m
            if log.resultT15 == nil && now.timeIntervalSince(log.timestamp) >= 900 {
                let change = (currentPrice - log.marketPrice) / log.marketPrice * 100.0
                let isSuccess = (log.finalAction == "BUY" && change > 0.1) || (log.finalAction == "SELL" && change < -0.1)
                
                log.resultT15 = PriceOutcome(price: currentPrice, changePercent: change, isSuccess: isSuccess)
                logs[i] = log // Update struct in array
                print("🧠 Chiron Learned: \(log.symbol) result T+15m: \(change)%")
            }
            
            // Check T+60m
            if log.resultT60 == nil && now.timeIntervalSince(log.timestamp) >= 3600 {
                let change = (currentPrice - log.marketPrice) / log.marketPrice * 100.0
                let isSuccess = (log.finalAction == "BUY" && change > 0.2) || (log.finalAction == "SELL" && change < -0.2)
                
                log.resultT60 = PriceOutcome(price: currentPrice, changePercent: change, isSuccess: isSuccess)
                logs[i] = log
                print("🧠 Chiron Learned: \(log.symbol) result T+60m: \(change)%")
            }
        }
    }
    
    /// Calculates the 'Trust Score' for each module based on historical accuracy.
    /// Returns a multiplier (e.g., 0.5 to 2.0). 1.0 is neutral.
    func getModuleReliability() -> [String: Double] {
        var scores: [String: Double] = [:]
        var counts: [String: Int] = [:]
        
        // Modules to track
        let modules = ["Orion", "Hermes", "Atlas", "Aether", "Demeter", "Phoenix", "Athena"]
        for m in modules { 
            scores[m] = 1.0 // Start neutral
            counts[m] = 0
        }
        
        // Analyze finished logs
        let finishedLogs = logs.filter { $0.resultT15 != nil }
        
        for log in finishedLogs {
            guard let result = log.resultT15 else { continue }
            
            // For each module in this decision
            for (modName, op) in log.opinions {
                // Did the module agree with the successful move?
                // let direction = (result.changePercent > 0) ? "BUY" : "SELL" // Unused
                // let opAction = op.stance == "CLAIM" ? log.proposedAction : (op.stance == "SUPPORT" ? log.proposedAction : "HOLD") // Unused
                
                // Effective Action of module
                // If PROPOSED is BUY:
                //   SUPPORT -> BUY
                //   OBJECT -> SELL/HOLD
                
                // Let's look at raw alignment
                // If Price went UP and Module said BUY/SUPPORT(Buy) -> Good
                
                var moduleDidGood = false
                if log.proposedAction == "BUY" {
                    if result.changePercent > 0 {
                        // Price UP
                        if op.stance == "CLAIM" || op.stance == "SUPPORT" { moduleDidGood = true }
                    } else {
                        // Price DOWN
                         if op.stance == "OBJECT" { moduleDidGood = true }
                    }
                } else if log.proposedAction == "SELL" {
                    if result.changePercent < 0 {
                        // Price DOWN
                        if op.stance == "CLAIM" || op.stance == "SUPPORT" { moduleDidGood = true }
                    } else {
                        // Price UP
                        if op.stance == "OBJECT" { moduleDidGood = true }
                    }
                }
                
                // Reward / Punish
                let current = scores[modName] ?? 1.0
                if moduleDidGood {
                    scores[modName] = min(2.0, current + 0.05)
                } else {
                    scores[modName] = max(0.2, current - 0.10) // Penalize harder
                }
                counts[modName] = (counts[modName] ?? 0) + 1
            }
        }
        
        return scores
    }
    
    /// Simulates a learning cycle by creating fake history records (Demo Mode)
    // REMOVED: User requested strict adherence to real data. No simulations.
    /*
    func simulateLearning() {
        // ...
    }
    */
    
    // Helper for creating logs (kept private if needed for unit tests, but disabled for app)
    // private func createMockLog...
}
