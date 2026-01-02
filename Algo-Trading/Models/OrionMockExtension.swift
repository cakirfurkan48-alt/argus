import Foundation

extension OrionScoreResult {
    static func mock(for symbol: String) -> OrionScoreResult {
        return OrionScoreResult(
            symbol: symbol,
            score: 75.0,
            components: OrionComponentScores(
                trend: 25.0,
                momentum: 15.0,
                relativeStrength: 12.0,
                structure: 25.0,
                pattern: 8.0,
                volatility: 12.0,
                
                rsi: 55.0,
                macdHistogram: 0.15,
                
                isRsAvailable: true,
                trendDesc: "Güçlü Trend",
                momentumDesc: "Pozitif İvme",
                structureDesc: "Yapı Oluşuyor",
                patternDesc: "Nötr",
                rsDesc: "Endeks Üzeri",
                volDesc: "Stabil"
            ),
            verdict: "Güçlü Al",
            generatedAt: Date()
        )
    }
}
