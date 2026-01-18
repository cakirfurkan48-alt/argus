import Foundation

// MARK: - Alkindus Calibration Engine
/// The brain of Alkindus. Observes decisions, waits for maturation, and updates calibration.
/// Phase 1: Shadow Mode - Observes only, does not influence decisions.

actor AlkindusCalibrationEngine {
    static let shared = AlkindusCalibrationEngine()
    
    private let memoryStore = AlkindusMemoryStore.shared
    
    private init() {}
    
    // MARK: - Observe Decision (Called by ArgusDecisionEngine)
    
    /// Called when a new decision is made. Records it for future evaluation.
    func observe(
        symbol: String,
        action: String,
        moduleScores: [String: Double],
        regime: String,
        currentPrice: Double
    ) async {
        // Skip HOLD/ABSTAIN - only track actionable decisions
        guard action == "BUY" || action == "SELL" else { return }
        
        let observation = PendingObservation(
            symbol: symbol,
            decisionDate: Date(),
            action: action,
            moduleScores: moduleScores,
            regime: regime,
            priceAtDecision: currentPrice,
            horizons: [7, 15]
        )
        
        var pending = await memoryStore.loadPendingObservations()
        pending.append(observation)
        await memoryStore.savePendingObservations(pending)
        
        print("👁️ Alkindus: Yeni gözlem kaydedildi - \(symbol) \(action)")
    }
    
    // MARK: - Process Matured Decisions (Called periodically)
    
    /// Checks all pending observations and evaluates those that have matured.
    func processMaturedDecisions(currentPrices: [String: Double]) async -> Int {
        var pending = await memoryStore.loadPendingObservations()
        var evaluatedCount = 0
        
        for i in pending.indices {
            var observation = pending[i]
            
            // Check each horizon
            for horizon in observation.horizons {
                guard observation.isHorizonMature(horizon) else { continue }
                guard !observation.evaluatedHorizons.contains(horizon) else { continue }
                
                // Get current price
                guard let currentPrice = currentPrices[observation.symbol] else { continue }
                
                // Evaluate outcome
                let wasCorrect = evaluateOutcome(
                    action: observation.action,
                    entryPrice: observation.priceAtDecision,
                    currentPrice: currentPrice
                )
                
                // Update calibration for each module that voted
                for (module, score) in observation.moduleScores {
                    let bracket = scoreToBracket(score)
                    await memoryStore.recordOutcome(
                        module: module,
                        scoreBracket: bracket,
                        wasCorrect: wasCorrect,
                        regime: observation.regime
                    )
                    
                    // Phase 2: Track anomaly detection data
                    await AlkindusAnomalyDetector.shared.recordModulePerformance(
                        module: module,
                        score: score,
                        wasCorrect: wasCorrect
                    )
                }
                
                // Phase 2: Track correlation data
                await AlkindusCorrelationTracker.shared.recordCorrelation(
                    modules: observation.moduleScores,
                    wasCorrect: wasCorrect
                )
                
                // Mark this horizon as evaluated
                observation.evaluatedHorizons.append(horizon)
                evaluatedCount += 1
                
                let result = wasCorrect ? "✅ DOĞRU" : "❌ YANLIŞ"
                print("👁️ Alkindus: T+\(horizon) değerlendirme - \(observation.symbol) \(result)")
            }
            
            pending[i] = observation
        }
        
        // Remove fully evaluated observations
        pending = pending.filter { !$0.isFullyEvaluated }
        await memoryStore.savePendingObservations(pending)
        
        return evaluatedCount
    }
    
    // MARK: - Outcome Evaluation
    
    private func evaluateOutcome(action: String, entryPrice: Double, currentPrice: Double) -> Bool {
        let change = (currentPrice - entryPrice) / entryPrice
        
        switch action {
        case "BUY":
            // BUY is correct if price went up
            return change > 0
        case "SELL":
            // SELL is correct if price went down (or we avoided loss)
            return change < 0
        default:
            return false
        }
    }
    
    // MARK: - Score to Bracket Mapping
    
    private func scoreToBracket(_ score: Double) -> String {
        switch score {
        case 80...100: return "80-100"
        case 60..<80: return "60-80"
        case 40..<60: return "40-60"
        case 20..<40: return "20-40"
        default: return "0-20"
        }
    }
    
    // MARK: - Get Current Stats (For UI)
    
    func getCurrentStats() async -> AlkindusStats {
        let calibration = await memoryStore.loadCalibration()
        let pending = await memoryStore.loadPendingObservations()
        
        return AlkindusStats(
            calibration: calibration,
            pendingCount: pending.count,
            lastUpdated: calibration.lastUpdated
        )
    }
}

// MARK: - Stats Model for UI

struct AlkindusStats {
    let calibration: CalibrationData
    let pendingCount: Int
    let lastUpdated: Date
    
    // Get top performing module
    var topModule: (name: String, hitRate: Double)? {
        var best: (String, Double)? = nil
        
        for (module, cal) in calibration.modules {
            // Consider only 60+ brackets
            let highBrackets = cal.brackets.filter { $0.key == "60-80" || $0.key == "80-100" }
            let totalAttempts = highBrackets.values.reduce(0) { $0 + $1.attempts }
            let totalCorrect = highBrackets.values.reduce(0) { $0 + $1.correct }
            
            guard totalAttempts >= 5 else { continue } // Minimum sample size
            
            let rate = Double(totalCorrect) / Double(totalAttempts)
            if best == nil || rate > best!.1 {
                best = (module, rate)
            }
        }
        
        return best
    }
    
    // Get weakest module
    var weakestModule: (name: String, hitRate: Double)? {
        var worst: (String, Double)? = nil
        
        for (module, cal) in calibration.modules {
            let totalAttempts = cal.brackets.values.reduce(0) { $0 + $1.attempts }
            let totalCorrect = cal.brackets.values.reduce(0) { $0 + $1.correct }
            
            guard totalAttempts >= 5 else { continue }
            
            let rate = Double(totalCorrect) / Double(totalAttempts)
            if worst == nil || rate < worst!.1 {
                worst = (module, rate)
            }
        }
        
        return worst
    }
}
