import Foundation

// MARK: - Chiron Module Weights (Engine-Aware)
/// Weights for Corse/Pulse specific evaluation with metadata
struct ChironModuleWeights: Codable, Sendable {
    var orion: Double
    var atlas: Double
    var phoenix: Double
    var aether: Double
    var hermes: Double
    var cronos: Double
    
    let updatedAt: Date
    let confidence: Double
    let reasoning: String
    
    // Default balanced weights
    static var defaultCorse: ChironModuleWeights {
        ChironModuleWeights(
            orion: 0.20,
            atlas: 0.35,  // Corse = Uzun vade = Fundamentals ağırlıklı
            phoenix: 0.20,
            aether: 0.15,
            hermes: 0.05,
            cronos: 0.05,
            updatedAt: Date(),
            confidence: 0.5,
            reasoning: "Varsayılan Corse ağırlıkları (uzun vade, fundamental odaklı)"
        )
    }
    
    static var defaultPulse: ChironModuleWeights {
        ChironModuleWeights(
            orion: 0.35,  // Pulse = Kısa vade = Teknik ağırlıklı
            atlas: 0.10,
            phoenix: 0.30,
            aether: 0.10,
            hermes: 0.10,
            cronos: 0.05,
            updatedAt: Date(),
            confidence: 0.5,
            reasoning: "Varsayılan Pulse ağırlıkları (kısa vade, momentum odaklı)"
        )
    }
    
    var totalWeight: Double {
        orion + atlas + phoenix + aether + hermes + cronos
    }
    
    func normalized() -> ChironModuleWeights {
        let total = totalWeight
        guard total > 0 else { return self }
        return ChironModuleWeights(
            orion: orion / total,
            atlas: atlas / total,
            phoenix: phoenix / total,
            aether: aether / total,
            hermes: hermes / total,
            cronos: cronos / total,
            updatedAt: updatedAt,
            confidence: confidence,
            reasoning: reasoning
        )
    }
}

// MARK: - Chiron Weight Store
@MainActor
final class ChironWeightStore {
    static let shared = ChironWeightStore()
    
    // symbol -> engine -> weights
    private var matrix: [String: [AutoPilotEngine: ChironModuleWeights]] = [:]
    
    // Persistence path
    private let storePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ChironWeights.json")
    }()
    
    init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Get weights for a specific symbol and engine
    func getWeights(symbol: String, engine: AutoPilotEngine) -> ChironModuleWeights {
        // 1. Symbol-specific override exists?
        if let symbolWeights = matrix[symbol], let engineWeights = symbolWeights[engine] {
            return engineWeights
        }
        
        // 2. Return defaults
        switch engine {
        case .corse:
            return .defaultCorse
        case .pulse:
            return .defaultPulse
        default:
            return .defaultPulse // Fallback
        }
    }
    
    /// Update weights for a symbol/engine pair
    func updateWeights(symbol: String, engine: AutoPilotEngine, weights: ChironModuleWeights) {
        if matrix[symbol] == nil {
            matrix[symbol] = [:]
        }
        matrix[symbol]?[engine] = weights.normalized()
        
        saveToDisk()
    }
    
    /// Get all stored weights (for UI display)
    func getAllWeights() -> [String: [AutoPilotEngine: ChironModuleWeights]] {
        return matrix
    }
    
    /// Check if symbol has custom weights
    func hasCustomWeights(symbol: String) -> Bool {
        return matrix[symbol] != nil
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            // Convert to serializable format
            var serializable: [String: [String: ChironModuleWeights]] = [:]
            for (symbol, engines) in matrix {
                var engineDict: [String: ChironModuleWeights] = [:]
                for (engine, weights) in engines {
                    engineDict[engine.rawValue] = weights
                }
                serializable[symbol] = engineDict
            }
            
            let data = try JSONEncoder().encode(serializable)
            try data.write(to: storePath)
            print("💾 ChironWeightStore: Saved to disk")
        } catch {
            print("❌ ChironWeightStore: Save failed - \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storePath.path) else { return }
        
        do {
            let data = try Data(contentsOf: storePath)
            let serializable = try JSONDecoder().decode([String: [String: ChironModuleWeights]].self, from: data)
            
            // Convert back to proper types
            for (symbol, engines) in serializable {
                matrix[symbol] = [:]
                for (engineRaw, weights) in engines {
                    if let engine = AutoPilotEngine(rawValue: engineRaw) {
                        matrix[symbol]?[engine] = weights
                    }
                }
            }
            print("📂 ChironWeightStore: Loaded \(matrix.count) symbols from disk")
        } catch {
            print("❌ ChironWeightStore: Load failed - \(error)")
        }
    }
}
