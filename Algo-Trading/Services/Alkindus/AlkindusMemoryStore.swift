import Foundation

// MARK: - Alkindus Memory Store
/// Manages persistent storage for Alkindus calibration data.
/// Uses JSON files to store aggregated statistics (not raw events).

actor AlkindusMemoryStore {
    static let shared = AlkindusMemoryStore()
    
    // MARK: - Paths
    private let basePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory")
    }()
    
    private var calibrationPath: URL { basePath.appendingPathComponent("calibration.json") }
    private var pendingPath: URL { basePath.appendingPathComponent("pending_observations.json") }
    
    private init() {
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
    }
    
    // MARK: - Load Calibration Data
    func loadCalibration() async -> CalibrationData {
        guard let data = try? Data(contentsOf: calibrationPath),
              let decoded = try? JSONDecoder().decode(CalibrationData.self, from: data) else {
            return CalibrationData.empty
        }
        return decoded
    }
    
    // MARK: - Save Calibration Data
    func saveCalibration(_ data: CalibrationData) async {
        var updated = data
        updated.lastUpdated = Date()
        
        if let encoded = try? JSONEncoder().encode(updated) {
            try? encoded.write(to: calibrationPath)
        }
    }
    
    // MARK: - Pending Observations (Awaiting Maturation)
    func loadPendingObservations() async -> [PendingObservation] {
        guard let data = try? Data(contentsOf: pendingPath),
              let decoded = try? JSONDecoder().decode([PendingObservation].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func savePendingObservations(_ observations: [PendingObservation]) async {
        if let encoded = try? JSONEncoder().encode(observations) {
            try? encoded.write(to: pendingPath)
        }
    }
    
    // MARK: - Update Module Calibration
    func recordOutcome(module: String, scoreBracket: String, wasCorrect: Bool, regime: String) async {
        var data = await loadCalibration()
        
        // Update module bracket
        if data.modules[module] == nil {
            data.modules[module] = ModuleCalibration(brackets: [:])
        }
        
        if data.modules[module]?.brackets[scoreBracket] == nil {
            data.modules[module]?.brackets[scoreBracket] = BracketStats(attempts: 0, correct: 0)
        }
        
        data.modules[module]?.brackets[scoreBracket]?.attempts += 1
        if wasCorrect {
            data.modules[module]?.brackets[scoreBracket]?.correct += 1
        }
        
        // Update regime insight
        if data.regimes[regime] == nil {
            data.regimes[regime] = RegimeInsight(moduleAttempts: [:], moduleCorrect: [:])
        }
        
        data.regimes[regime]?.moduleAttempts[module, default: 0] += 1
        if wasCorrect {
            data.regimes[regime]?.moduleCorrect[module, default: 0] += 1
        }
        
        await saveCalibration(data)
    }
    
    // MARK: - Get Hit Rate
    func getHitRate(module: String, scoreBracket: String) async -> Double? {
        let data = await loadCalibration()
        guard let stats = data.modules[module]?.brackets[scoreBracket] else { return nil }
        return stats.hitRate
    }
}

// MARK: - Data Models

struct CalibrationData: Codable {
    var modules: [String: ModuleCalibration]
    var regimes: [String: RegimeInsight]
    var lastUpdated: Date
    var version: String
    
    static var empty: CalibrationData {
        CalibrationData(
            modules: [:],
            regimes: [:],
            lastUpdated: Date(),
            version: "1.0"
        )
    }
}

struct ModuleCalibration: Codable {
    var brackets: [String: BracketStats] // "70-80", "80-100", etc.
}

struct BracketStats: Codable {
    var attempts: Int
    var correct: Int
    
    var hitRate: Double {
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }
}

struct RegimeInsight: Codable {
    var moduleAttempts: [String: Int]
    var moduleCorrect: [String: Int]
    
    func hitRate(for module: String) -> Double {
        let attempts = moduleAttempts[module] ?? 0
        let correct = moduleCorrect[module] ?? 0
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }
}

struct PendingObservation: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let decisionDate: Date
    let action: String
    let moduleScores: [String: Double]
    let regime: String
    let priceAtDecision: Double
    let horizons: [Int] // [7, 15]
    var evaluatedHorizons: [Int] // Horizons already evaluated
    
    init(symbol: String, decisionDate: Date, action: String, moduleScores: [String: Double], regime: String, priceAtDecision: Double, horizons: [Int] = [7, 15]) {
        self.id = UUID()
        self.symbol = symbol
        self.decisionDate = decisionDate
        self.action = action
        self.moduleScores = moduleScores
        self.regime = regime
        self.priceAtDecision = priceAtDecision
        self.horizons = horizons
        self.evaluatedHorizons = []
    }
    
    // Check if a horizon is ready to be evaluated
    func isHorizonMature(_ horizon: Int, currentDate: Date = Date()) -> Bool {
        let targetDate = Calendar.current.date(byAdding: .day, value: horizon, to: decisionDate) ?? decisionDate
        return currentDate >= targetDate && !evaluatedHorizons.contains(horizon)
    }
    
    // All horizons evaluated?
    var isFullyEvaluated: Bool {
        Set(evaluatedHorizons) == Set(horizons)
    }
}
