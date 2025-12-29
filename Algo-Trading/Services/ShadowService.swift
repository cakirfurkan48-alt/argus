import Foundation

/// Phase 3: Reality Penalty (System Hardening)
/// Handles shadow trade recording with realistic slippage and commissions.
class ShadowService {
    static let shared = ShadowService()
    
    // Constants
    private let slippagePercent = 0.001 // 0.1%
    private let commissionPerTrade = 1.0 // $1.00
    
    private init() {}
    
    /// Records a shadow trade execution with applied reality penalties.
    func executeShadowTrade(symbol: String, decision: ArgusDecisionResult, currentQuote: Quote, macro: Double, vix: Double) {
        // 1. Calculate Reality-Adjusted Price
        // Buy: Ask + Slippage
        // Sell: Bid - Slippage (Not implemented for entry, but typical for exit)
        // For Entry (Buy):
        let rawPrice = currentQuote.currentPrice
        let adjustedEntryPrice = rawPrice * (1.0 + slippagePercent)
        
        // 2. Log System Event
        print("🥊 SHADOW REALITY: \(symbol) Raw: \(rawPrice) -> Adj: \(adjustedEntryPrice) (Slip: 0.1%)")
        
        // 3. Persist via Learning Manager
        // We log the *adjusted* price so the PnL calculation later honors the penalty.
        // We also implicitly account for commission by deducting it from the *virtual balance* if we tracked it,
        // but since we track PnL per trade, we'll store the commission cost metadata if possible.
        // For now, LearningPersistenceManager just stores 'price'.
        // To be strict, we really want the EXIT to also have slippage. 
        // Shadow Trades are "opened" here. The "close" logic needs to apply slippage too.
        
        // Store the entry
        LearningPersistenceManager.shared.logShadowEntry(
            symbol: symbol,
            price: adjustedEntryPrice, // Penalty applied
            atlas: decision.atlasScore,
            orion: decision.orionScore,
            aether: decision.aetherScore,
            vix: vix
        )
    }
    
    // Helper to calculate exit pnl with penalties
    func calculateRealizedPnL(entryPrice: Double, exitPriceRaw: Double, qty: Double) -> Double {
        let exitPriceAdj = exitPriceRaw * (1.0 - slippagePercent)
        let grossPnL = (exitPriceAdj - entryPrice) * qty
        return grossPnL - (commissionPerTrade * 2) // Entry + Exit Comm
    }
}
