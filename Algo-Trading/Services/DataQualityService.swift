import Foundation

/// Represents the confidence level of the underlying data (0-100)
struct DataConfidence: Codable {
    let global: Double
    let atlas: Double
    let orion: Double
    let aether: Double
    let hermes: Double
    
    var isSafeToTrade: Bool { global >= 80 }
    var isViewable: Bool { global >= 50 }
    
    // Partiality Flags
    var isFundamentalPartial: Bool { atlas < 50 }
    var isTechnicalPartial: Bool { orion < 50 }
    var isMacroPartial: Bool { aether < 50 }
    
    static let zero = DataConfidence(global: 0, atlas: 0, orion: 0, aether: 0, hermes: 0)
}

final class DataQualityService {
    static let shared = DataQualityService()
    
    private init() {}
    
    /// Main Entry Point: Calculate holistic confidence
    func calculateConfidence(
        atlasCoverage: Double, // 0-100
        candles: [Candle]?,
        aetherRating: MacroEnvironmentRating?,
        hermesInsights: [NewsInsight]?
    ) -> DataConfidence {
        
        let atlasConf = atlasCoverage // Already computed by FundamentalScoreEngine
        let orionConf = calculateOrionConfidence(candles)
        let aetherConf = calculateAetherConfidence(aetherRating)
        let hermesConf = calculateHermesConfidence(hermesInsights)
        
        // Ensure Global Confidence Logic
        // "globalDataConfidence = min(confAtlas, confOrion, confAether, confHermes)"
        let global = min(atlasConf, orionConf, aetherConf, hermesConf)
        
        return DataConfidence(
            global: global,
            atlas: atlasConf,
            orion: orionConf,
            aether: aetherConf,
            hermes: hermesConf
        )
    }
    
    // MARK: - Component Logic
    
    // allow separate calls if needed
    func calculateAtlasConfidence(_ coverage: Double) -> Double {
        return max(0, min(coverage, 100))
    }
    
    private func calculateOrionConfidence(_ candles: [Candle]?) -> Double {
        guard let candles = candles, !candles.isEmpty else { return 0 }
        let count = candles.count
        
        if count >= 60 { return 100 }
        if count >= 30 { return 70 }
        return 40 // Too few candles for reliable trend
    }
    
    private func calculateAetherConfidence(_ rating: MacroEnvironmentRating?) -> Double {
        guard let rating = rating else { return 0 }
        
        // Logic: How many components were missing?
        // missingComponents is [String]
        let missingCount = rating.missingComponents.count
        
        switch missingCount {
        case 0: return 100
        case 1: return 80
        case 2: return 60
        default: return 40
        }
    }
    
    private func calculateHermesConfidence(_ insights: [NewsInsight]?) -> Double {
        // If no news found, is it low confidence?
        // Or if we found 0 news, does it mean we are flying blind?
        // Let's assume if array is nil -> 0. If empty [], maybe 50?
        guard let insights = insights else { return 50 } // Default medium if not even fetched
        if insights.isEmpty { return 60 } // No news is sometimes good news, or lack of info.
        
        // Check confidence of the insights themselves (AI output confidence)
        // Average confidence of the last few news
        let relevant = insights.prefix(5)
        let totalConf = relevant.reduce(0.0) { $0 + $1.confidence }
        let avgConf = totalConf / Double(relevant.count)
        
        // Map 0.0-1.0 to 0-100
        // But also factor in quantity. 1 reliable news > 10 garbage news.
        
        return max(50, avgConf * 100)
    }
}
