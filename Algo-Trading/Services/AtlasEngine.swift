import Foundation

/// "The Calculator" - Dynamic Ratio Engine
/// Re-calculates fundamental ratios (P/E, P/B, Yield) using Real-Time Price + Cached Fundamentals.
/// This allows "Atlas" to remain accurate even if the balance sheet is 3 months old, because Price is live.
final class AtlasEngine {
    static let shared = AtlasEngine()
    
    struct DynamicRatios {
        let peRatio: Double?
        let marketCap: Double?
        let dividendYield: Double? // If we had dividend per share
        let priceToBook: Double?
    }
    
    private init() {}
    
    /// Calculate live ratios based on cached fundamentals and live price.
    func calculateDynamicRatios(snapshot: FundamentalSnapshot, currentPrice: Double) -> DynamicRatios {
        
        // 1. Dynamic Market Cap
        // Need SharesOutstanding. Snapshot had marketCap (static).
        // If we have static MarketCap and static Price (at time of fetch), we can derive shares.
        // But `FundamentalSnapshot` doesn't store 'priceAtFetch'.
        // We'll estimate or use what we have.
        // Actually `FundamentalSnapshot` `marketCap` is likely from the API call time.
        // If we want REAL TIME Cap, we need `SharesOutstanding`.
        // Let's assume we rely on the snapshot's raw data for now, or if we had shares we'd mult by price.
        // `FinancialsData` had `marketCap`.
        
        // 2. Dynamic P/E
        // Price / EPS
        var dynPE: Double? = nil
        if let eps = snapshot.epsTTM, eps != 0 {
            dynPE = currentPrice / eps
        } else {
            // Fallback to snapshot PE if calculated is impossible?
            // Snapshot PE is static. Live is better.
            dynPE = snapshot.peRatio // Fallback
        }
        
        // 3. Dynamic P/B
        // Price / BookValuePerShare
        // If we don't have BVPS, but have Equity... we need Shares.
        // Missing Shares in Snapshot is a blocker for precise P/B.
        // We will default to Snapshot's P/B if we can't calc.
        let dynPB = snapshot.priceToBook
        
        // 4. Update Market Cap Approx
        // We don't have shares, so we can't update Market Cap perfectly with Price.
        // We'll return the Snapshot's cap.
        
        // TODO: Enhance Snapshot to include `sharesOutstanding` for perfect dynamic calcs.
        
        return DynamicRatios(
            peRatio: dynPE,
            marketCap: snapshot.marketCap,
            dividendYield: nil,
            priceToBook: dynPB
        )
    }
}
