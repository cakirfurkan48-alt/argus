import Foundation
import SwiftUI

// MARK: - Models

struct ChimeraDna: Codable, Sendable {
    let momentum: Double // 0-100 (Normalized from Orion 0-25)
    let trend: Double    // 0-100 (Normalized from Orion 0-25)
    let value: Double    // 0-100 (Atlas/Titan)
    let sentiment: Double // 0-100 (Hermes)
    let structure: Double // 0-100 (Fiyat Yapısı - eski volatility)
}

struct ChimeraFusionResult: Sendable {
    let finalScore: Double // 0-100
    let dna: ChimeraDna
    let signals: [ChimeraSignal]
    let primaryDriver: String // e.g., "MOMENTUM"
    let regimeContext: String
}

struct ChimeraSignal: Identifiable, Sendable {
    let id = UUID()
    let type: ChimeraSignalType
    let title: String
    let description: String
    let severity: Double // 0-1 (1 = Critical)
}

enum ChimeraSignalType: String, Sendable {
    case deepValueBuy = "Deep Value"
    case bullTrap = "Bull Trap"
    case momentumBreakout = "Breakout"
    case fallingKnife = "Falling Knife"
    case sentimentDivergence = "Sentiment Div"
    case perfectStorm = "Perfect Storm"
}

// MARK: - Engine

final class ChimeraSynergyEngine: @unchecked Sendable {
    static let shared = ChimeraSynergyEngine()
    
    private init() {}
    
    /// Fuses data from all modules into a single Chimera Result.
    /// Uses Chiron's regime to weight the components.
    func fuse(
        symbol: String,
        orion: OrionScoreResult?,
        hermesImpactScore: Double?,
        titanScore: Double?,
        currentPrice: Double,
        marketRegime: MarketRegime
    ) -> ChimeraFusionResult {
        
        // 1. NORMALIZE INPUTS (FIX: Scale correction)
        // Orion components: trend=0-25, momentum=0-25, structure=0-35
        let rawMomentum = orion?.components.momentum ?? 12.5
        let rawTrend = orion?.components.trend ?? 12.5
        let rawStructure = orion?.components.structure ?? 17.5
        
        let momentumScore = (rawMomentum / 25.0) * 100.0 // 0-100
        let trendScore = (rawTrend / 25.0) * 100.0       // 0-100
        let structureScore = (rawStructure / 35.0) * 100.0 // 0-100
        
        // Value from Atlas/Titan (already 0-100)
        let valueScore = titanScore ?? 50.0
        
        // Sentiment from Hermes (already 0-100)
        let sentimentScore = hermesImpactScore ?? 50.0
        
        let dna = ChimeraDna(
            momentum: momentumScore,
            trend: trendScore,
            value: valueScore,
            sentiment: sentimentScore,
            structure: structureScore
        )
        
        // 2. REGIME-BASED WEIGHTING (Using Chiron's logic)
        var wMom = 0.2
        var wTrend = 0.2
        var wVal = 0.2
        var wSent = 0.2
        var wStruct = 0.2
        
        switch marketRegime {
        case .riskOff:
            // Defense: Value & Structure dominate
            wMom = 0.05; wTrend = 0.10; wVal = 0.40; wStruct = 0.35; wSent = 0.10
        case .trend:
            // Attack: Trend & Momentum dominate
            wMom = 0.35; wTrend = 0.40; wVal = 0.05; wStruct = 0.05; wSent = 0.15
        case .newsShock:
            // Hype: Sentiment dominates
            wMom = 0.10; wTrend = 0.10; wVal = 0.0; wStruct = 0.0; wSent = 0.80
        case .chop:
            // Caution: Value & Sentiment (contrarian)
            wMom = 0.10; wTrend = 0.10; wVal = 0.40; wSent = 0.20; wStruct = 0.20
        case .neutral:
            // Balanced
            wMom = 0.2; wTrend = 0.2; wVal = 0.2; wSent = 0.2; wStruct = 0.2
        }
        
        let finalScore = (momentumScore * wMom) +
                         (trendScore * wTrend) +
                         (valueScore * wVal) +
                         (sentimentScore * wSent) +
                         (structureScore * wStruct)
        
        // 3. SIGNAL DETECTION (Corrected thresholds for 0-100 scale)
        var signals: [ChimeraSignal] = []
        
        // Deep Value: High value + Low momentum + Positive sentiment
        if valueScore > 70 && momentumScore < 40 && sentimentScore > 50 {
            signals.append(ChimeraSignal(
                type: .deepValueBuy,
                title: "Deep Value",
                description: "Teknik dipte ama temel değer güçlü.",
                severity: 0.8
            ))
        }
        
        // Bull Trap: High sentiment + Low value + Weak momentum
        if sentimentScore > 75 && valueScore < 40 && momentumScore < 50 {
            signals.append(ChimeraSignal(
                type: .bullTrap,
                title: "Bull Trap",
                description: "Yüksek hype ama zayıf temel.",
                severity: 0.9
            ))
        }
        
        // Perfect Storm: All stars aligned
        if momentumScore > 70 && sentimentScore > 70 && trendScore > 70 && valueScore > 60 {
            signals.append(ChimeraSignal(
                type: .perfectStorm,
                title: "Perfect Storm",
                description: "Tüm faktörler uyumlu!",
                severity: 1.0
            ))
        }
        
        // Falling Knife: Strong downtrend + Negative sentiment
        if trendScore < 30 && momentumScore < 30 && sentimentScore < 40 {
            signals.append(ChimeraSignal(
                type: .fallingKnife,
                title: "Falling Knife",
                description: "Düşüş teyitli - yakalaması riskli.",
                severity: 0.85
            ))
        }
        
        // 4. IDENTIFY PRIMARY DRIVER
        let contributions: [(String, Double)] = [
            ("MOM", momentumScore * wMom),
            ("TREND", trendScore * wTrend),
            ("DEĞER", valueScore * wVal),
            ("ALGI", sentimentScore * wSent),
            ("YAPI", structureScore * wStruct)
        ]
        let driver = contributions.max(by: { $0.1 < $1.1 })?.0 ?? "DENGE"
        
        return ChimeraFusionResult(
            finalScore: finalScore,
            dna: dna,
            signals: signals,
            primaryDriver: driver,
            regimeContext: marketRegime.descriptor
        )
    }
}
