import Foundation

// MARK: - Argus Core Combiner

/// Argus Core’un 4 bacaktan skor toplayıp tek karar vermesi
struct ArgusCoreInput {
    let technicalScore: Double?      // Orion
    let fundamentalScore: Double?    // Atlas
    let macroScore: Double?          // Aether
    let newsScore: Double?           // Hermes
    let athenaScore: Double?         // Athena (Factor)
    
    let coverage: DataCoverage
}

struct ArgusCoreOutput {
    let finalScore: Double           // 0-100
    let letterGrade: String          // A+, B, C, D, F
    let action: LabAction            // buy/sell/hold/avoid
}

/// Çıplak temel ağırlıklar (veri tamken)
/// Defaults updated for Athena integration (Core Strategy)
struct ArgusCoreWeights {
    var fundamental: Double = 0.30   // Atlas
    var athena: Double = 0.25        // Athena
    var macro: Double = 0.20         // Aether
    var technical: Double = 0.15     // Orion
    var news: Double = 0.10          // Hermes
}

final class ArgusCoreCombiner {
    static let shared = ArgusCoreCombiner()
    private init() {}
    
    func combine(input: ArgusCoreInput,
                 baseWeights: ArgusCoreWeights = ArgusCoreWeights()) -> ArgusCoreOutput {
        
        // 1) Hangi bacaktan veri var, hangisinden yok?
        var weightedParts: [(score: Double, weight: Double)] = []
        
        func addIfAvailable(score: Double?, baseWeight: Double, quality: Double) {
            guard let s = score else { return }
            // veri kalitesine göre ağırlığı azalt/arttır
            let effectiveWeight = baseWeight * quality
            guard effectiveWeight > 0 else { return }
            weightedParts.append((score: s, weight: effectiveWeight))
        }
        
        addIfAvailable(score: input.technicalScore,
                       baseWeight: baseWeights.technical,
                       quality: input.coverage.technical.quality)
        
        addIfAvailable(score: input.fundamentalScore,
                       baseWeight: baseWeights.fundamental,
                       quality: input.coverage.fundamental.quality)
        
        addIfAvailable(score: input.athenaScore,
                       baseWeight: baseWeights.athena,
                       quality: input.coverage.fundamental.quality)
        
        addIfAvailable(score: input.macroScore,
                       baseWeight: baseWeights.macro,
                       quality: input.coverage.macro.quality)
        
        addIfAvailable(score: input.newsScore,
                       baseWeight: baseWeights.news,
                       quality: input.coverage.news.quality)
        
        // Hiç bir şey yoksa → nötr çık
        guard !weightedParts.isEmpty else {
            return ArgusCoreOutput(finalScore: 50, letterGrade: "C", action: .hold)
        }
        
        // 2) Ağırlıkları normalize et
        let totalWeight = weightedParts.reduce(0.0) { $0 + $1.weight }
        let normalized = weightedParts.map { part in
            (score: part.score, weight: part.weight / totalWeight)
        }
        
        // 3) Nihai skor
        let finalScore = normalized.reduce(0.0) { acc, part in
            acc + part.score * part.weight
        }
        
        // 4) Harf notu
        let grade: String
        switch finalScore {
        case 90...100: grade = "A+"
        case 80..<90:  grade = "A"
        case 70..<80:  grade = "B"
        case 60..<70:  grade = "C"
        case 50..<60:  grade = "D"
        default:       grade = "F"
        }
        
        // 5) Aksiyon
        let action: LabAction
        switch finalScore {
        case 80...100:
            action = .buy
        case 65..<80:
            action = .hold
        case 50..<65:
            action = .avoid
        default:
            action = .sell
        }
        
        return ArgusCoreOutput(finalScore: finalScore,
                               letterGrade: grade,
                               action: action)
    }
}
