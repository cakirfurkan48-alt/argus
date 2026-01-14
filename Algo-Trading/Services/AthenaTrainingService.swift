import Foundation

/// Athena Learning Service (RL-Lite)
/// Collects experiences (Trade Result + Input Features) and updates model weights
/// based on what actually worked in the market.
final class AthenaTrainingService {
    static let shared = AthenaTrainingService()
    
    private var experiences: [AthenaExperience] = []
    
    // Learning Rate (Alpha)
    private let learningRate: Double = 0.05
    
    private init() {}
    
    /// Record a trade outcome
    func recordExperience(
        symbol: String,
        features: AthenaFeatureVector,
        outcome: Double, // % Profit/Loss
        holdingPeriod: Int
    ) {
        // Calculate Reward (Simple: Profit is good, Loss is bad)
        // Normalize: 5% profit = 1.0 reward, -5% loss = -1.0 reward
        let reward = max(-1.0, min(1.0, outcome / 5.0))
        
        let experience = AthenaExperience(
            date: Date(),
            symbol: symbol,
            features: features,
            outcome: outcome,
            reward: reward
        )
        
        experiences.append(experience)
        print("🧠 Athena learned from \(symbol): Outcome \(String(format: "%.2f", outcome))% -> Reward \(String(format: "%.2f", reward))")
        
        // Trigger online learning if enough data
        if experiences.count % 5 == 0 {
            trainWeights()
        }
    }
    
    /// Simple Gradient Ascent (Reinforcement Learning)
    /// Adjust weights to favor features that led to positive rewards
    private func trainWeights() {
        // In a real full ML system, we would batch train or use an optimizer.
        // Here we do a simple "Nudge" (Heuristic Hill Climbing).
        
        // 1. Get current weights (Need to expose them from Engine, for now we effectively 'guess' or need read access)
        // Ideally Engine should expose read/write. For this MVP, we will simulate the 'delta'.
        
        // Let's assume we want to find which factor correlates most with Reward
        
        var valueDelta = 0.0
        var qualityDelta = 0.0
        var momentumDelta = 0.0
        
        for exp in experiences.suffix(10) { // Look at last 10
            // If Reward is Positive, increase weight of high-score factors
            // If Reward is Negative, decrease weight of high-score factors
            
            let direction = exp.reward // + or -
            
            // Normalize inputs 0..1
            let v = exp.features.valueScore / 100.0
            let q = exp.features.qualityScore / 100.0
            let m = exp.features.momentumScore / 100.0
            
            // Update delta based on "Input * Error" concept
            valueDelta += direction * (v - 0.5) // Center around 0.5
            qualityDelta += direction * (q - 0.5)
            momentumDelta += direction * (m - 0.5)
        }
        
        // Apply Learning Rate
        valueDelta *= learningRate
        qualityDelta *= learningRate
        momentumDelta *= learningRate
        
        print("🧠 Athena Training Update: Value \(String(format: "%.4f", valueDelta)), Quality \(String(format: "%.4f", qualityDelta))")
        
        // Note: In a real implementation, we would now call AthenaInferenceEngine.shared.updateWeights(...)
        // But we need to make weights accessible first.
    }
}
