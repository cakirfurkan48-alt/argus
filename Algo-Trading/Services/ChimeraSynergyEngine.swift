import Foundation
import SwiftUI

// MARK: - Models

struct ChimeraDna: Codable, Sendable {
    let momentum: Double // 0-100 (Orion)
    let trend: Double    // 0-100 (Orion/Phoenix)
    let value: Double    // 0-100 (Titan/Atlas)
    let sentiment: Double // 0-100 (Hermes)
    let volatility: Double // 0-100 (Higher score = SAFER / Lower Vol)
}

struct ChimeraFusionResult: Sendable {
    let finalScore: Double // 0-100
    let dna: ChimeraDna
    let signals: [ChimeraSignal]
    let primaryDriver: String // e.g., "MOMENTUM DRIVEN"
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
    case perfectStorm = "Perfect Storm" // Rare: All signals align
}

// MARK: - Engine

final class ChimeraSynergyEngine: @unchecked Sendable {
    static let shared = ChimeraSynergyEngine()
    
    private init() {}
    
    /// Fuses data from all modules into a single detailed Chimera Result.
    /// - Parameters:
    ///   - orion: Technical analysis result (OrionScoreResult)
    ///   - hermesImpactScore: News impact score from Hermes (0-100)
    ///   - titanScore: Fundamental score (0-100)
    ///   - currentPrice: Current stock price
    ///   - marketRegime: Current market regime from Chiron
    func fuse(
        symbol: String,
        orion: OrionScoreResult?,
        hermesImpactScore: Double?,
        titanScore: Double?,
        currentPrice: Double,
        marketRegime: MarketRegime
    ) -> ChimeraFusionResult {
        
        // 1. Normalize Inputs
        let momentumScore = orion?.components.momentum ?? 50.0
        let trendScore = orion?.components.trend ?? 50.0
        let valueScore = titanScore ?? 50.0
        let sentimentScore = hermesImpactScore ?? 50.0
        
        // Volatility: We estimate from Orion's components or use a default
        // Higher structure score implies lower volatility risk
        let structureScore = orion?.components.structure ?? 50.0
        let stabilityScore = structureScore // Use structure as proxy for stability
        
        let dna = ChimeraDna(
            momentum: momentumScore,
            trend: trendScore,
            value: valueScore,
            sentiment: sentimentScore,
            volatility: stabilityScore
        )
        
        // 2. Regime-Based Weighting (The CHIMERA Logic)
        var wMom = 0.2
        var wTrend = 0.2
        var wVal = 0.2
        var wSent = 0.2
        var wVol = 0.2
        
        switch marketRegime {
        case .riskOff:
            // Defense Mode: Value & Stability are King
            wMom = 0.05
            wTrend = 0.10
            wVal = 0.40
            wVol = 0.35
            wSent = 0.10
        case .trend:
            // Attack Mode: Trend & Momentum
            wMom = 0.35
            wTrend = 0.40
            wVal = 0.05
            wVol = 0.05
            wSent = 0.15
        case .newsShock:
            // Hype Mode: Sentiment is King
            wMom = 0.10
            wTrend = 0.10
            wVal = 0.0
            wVol = 0.0
            wSent = 0.80
        case .chop:
            // Caution Mode: Value & Sentiment (Contrarian)
            wMom = 0.10
            wTrend = 0.10
            wVal = 0.40
            wSent = 0.20
            wVol = 0.20
        case .neutral:
            // Balanced
            wMom = 0.2; wTrend = 0.2; wVal = 0.2; wSent = 0.2; wVol = 0.2
        }
        
        let rawWeightedScore = (momentumScore * wMom) +
                               (trendScore * wTrend) +
                               (valueScore * wVal) +
                               (sentimentScore * wSent) +
                               (stabilityScore * wVol)
        
        // 3. Signal Detection (Smart Divergence)
        var signals: [ChimeraSignal] = []
        
        // A. Deep Value (Cheap + Hated but improving or Cheap + Stable)
        if valueScore > 70 && momentumScore < 30 && sentimentScore > 50 {
            signals.append(ChimeraSignal(
                type: .deepValueBuy,
                title: "Deep Value Fırsatı",
                description: "Hisse teknik olarak dipte ama temel değer ve sentiment pozitif.",
                severity: 0.8
            ))
        }
        
        // B. Bull Trap (Hype + Bad Fundamentals + Waning Momentum)
        if sentimentScore > 80 && valueScore < 30 && momentumScore < 50 {
            signals.append(ChimeraSignal(
                type: .bullTrap,
                title: "Bull Trap Riski",
                description: "Yüksek haber coşkusu var ancak temel ve momentum zayıf.",
                severity: 0.9
            ))
        }
        
        // C. Perfect Storm
        if momentumScore > 80 && sentimentScore > 80 && trendScore > 80 {
            signals.append(ChimeraSignal(
                type: .perfectStorm,
                title: "Mükemmel Fırtına",
                description: "Teknik, Trend ve Sentiment tam uyum içinde yükseliyor.",
                severity: 1.0
            ))
        }
        
        // 4. Identify Driver
        let contributions: [(String, Double)] = [
            ("MOMENTUM", momentumScore * wMom),
            ("TREND", trendScore * wTrend),
            ("DEĞER", valueScore * wVal),
            ("ALGI", sentimentScore * wSent),
            ("İSTİKRAR", stabilityScore * wVol)
        ]
        let driver = contributions.max(by: { $0.1 < $1.1 })?.0 ?? "DENGELİ"
        
        return ChimeraFusionResult(
            finalScore: rawWeightedScore,
            dna: dna,
            signals: signals,
            primaryDriver: driver,
            regimeContext: marketRegime.descriptor
        )
    }
}
