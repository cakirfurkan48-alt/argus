import Foundation

// MARK: - Portfolio Risk Brain (v2.1)

final class RiskManagementService {
    static let shared = RiskManagementService()
    
    private init() {}
    
    // Standard Fixed Fractional Position Sizing
    // Formula: (Account Equity * Risk%) / (Entry - StopLoss)
    func calculatePositionSize(
        symbol: String,
        currentPrice: Double,
        stopLoss: Double,
        equity: Double,
        riskPct: Double = 2.0 // Standard 2%
    ) -> PositionRecommendation {
        
        let riskRatio = riskPct / 100.0
        let riskAmount = equity * riskRatio
        
        let riskPerShare = abs(currentPrice - stopLoss)
        
        // Safety: Avoid div by zero
        let safeRiskPerShare = riskPerShare < 0.01 ? (currentPrice * 0.05) : riskPerShare
        
        var shares = Int(riskAmount / safeRiskPerShare)
        
        // Sanity Check: Don't leverage > 2x even if stop is tight
        let maxPosValue = equity * 2.0
        if Double(shares) * currentPrice > maxPosValue {
            shares = Int(maxPosValue / currentPrice)
        }
        
        // Warnings
        var warnings: [String] = []
        let posValue = Double(shares) * currentPrice
        let posPct = (posValue / equity) * 100
        
        if posPct > 25 {
            warnings.append("Dikkat: Bu pozisyon portföyün %\(Int(posPct))'sini oluşturuyor.")
        }
        if riskPerShare / currentPrice > 0.15 {
            warnings.append("Stop mesafesi çok geniş (%15+). Volatilite yüksek.")
        }
        
        return PositionRecommendation(
            symbol: symbol,
            computedAt: Date(),
            currentPrice: currentPrice,
            stopLoss: stopLoss,
            accountEquity: equity,
            riskPerTradePct: riskPct,
            riskAmount: riskAmount,
            riskPerShare: safeRiskPerShare,
            recommendedShares: shares,
            positionValue: posValue,
            percentOfEquity: posPct,
            kellySuggestion: nil, // Calclated separately if needed
            warnings: warnings
        )
    }
    
    // Advanced: Kelly Criterion
    // Formula: K% = W - [(1-W) / R]
    // W = Win Rate (0.65), R = Win/Loss Ratio (1.5)
    func calculateKellySize(
        winRatePct: Double, // 65.0
        profitFactor: Double // Used as proxy for Win/Loss R or just R:R
    ) -> Double {
        let w = winRatePct / 100.0
        let r = profitFactor // Assuming PF ~ Avg Win / Avg Loss for simplicity here
        
        if r <= 0 { return 0 }
        
        let kellyPct = w - ((1 - w) / r)
        
        // Diluted Kelly (Half-Kelly is industry standard for safety)
        return max(0, kellyPct * 0.5) * 100 // Return as %
    }
}
