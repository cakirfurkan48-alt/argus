import Foundation

// MARK: - Strategy Lab Engine (Updated for Orion 3.0)
// Historical Simulator for Orion Technical Strategy

actor StrategyEvaluatorService {
    static let shared = StrategyEvaluatorService()
    
    private init() {}
    
    func runBacktest(symbol: String, candles: [Candle], config: BacktestConfig) async -> BacktestResult {
        // 1. Data Prep
        // We need enough history for indicators (60 bars minimum for Orion)
        let requiredLookback = 60
        
        // Determine start index based on config
        // Default to provided start date or calculate based on period logic if needed
        // For simplicity, we just run on available data or a fixed subset if specified
        
        let startCapital = config.initialCapital
        var capital = startCapital
        var shares = 0.0
        var entryPrice = 0.0
        var entryDate: Date = Date()
        var maxTradeHigh = 0.0 // Trailing Stop Tracker
        
        var trades: [BacktestTrade] = []
        var equityCurve: [EquityPoint] = []
        var maxEquity = capital
        var maxDrawdown = 0.0
        
        let sortedCandles = candles.sorted { $0.date < $1.date }
        
        guard sortedCandles.count > requiredLookback else {
            return emptyResult(symbol: symbol, config: config)
        }
        
        // Loop
        for i in requiredLookback..<sortedCandles.count {
            // Sliding Window for Analysis
            let startOfWindow = i - requiredLookback
            // Need enough candles for Orion
            let window = Array(sortedCandles[startOfWindow...i])
            
            let currentCandle = sortedCandles[i]
            let date = currentCandle.date
            let price = currentCandle.close
            
            // Analyze (Using Orion 3.0)
            // Use local calculation without SPY (Lite Mode) for speed in loop
            // Note: Calling generic function from Actor might require await if inferred isolated
            let orionResult = await OrionAnalysisService.shared.calculateOrionScore(
                symbol: symbol,
                candles: window,
                spyCandles: nil // Missing SPY in loop for performance/complexity reasons
            )
            
            let score = orionResult?.score ?? 50.0
            let components = orionResult?.components
            
            // Logic: Orion 3.0 Rules
            // 1. Trend Filter: Component Trend Score (0-30). > 20 is Strong.
            let isTrendUp = (components?.trend ?? 0) >= 18
            
            // 2. Buy Signal
            // Score >= 70
            let isBuySignal = (score >= 65 && isTrendUp) // Simplified for 3.0
            
            // 3. Sell Signal
            // Trend Broken (Score < 45)
            let isTrendBroken = score < 45
            
            // --- EXECUTION LOGIC ---
            
            // Check Exits first if holding
            if shares > 0 {
                // Update Max High for Trailing
                if price > maxTradeHigh { maxTradeHigh = price }
                
                // 1. Trailing Stop (8%)
                let trailingDrop = (maxTradeHigh - price) / maxTradeHigh
                let isTrailingHit = trailingDrop > 0.08
                
                // 2. Stop Loss Check (Hard Stop from entry)
                let pnlPct = (price - entryPrice) / entryPrice
                let stopUnconditional = pnlPct < -0.07 // 7% Hard Stop
                
                if stopUnconditional || isTrendBroken || isTrailingHit {
                    // SELL
                    let revenue = shares * price
                    capital += revenue
                    
                    // Fee (0.1% for simulation)
                    // Simplified: config.strategy doesn't explicitly store 'includeFees', assuming 0.1%
                    let fee = revenue * 0.001
                    capital -= fee
                    
                    let trade = BacktestTrade(
                        entryDate: entryDate,
                        exitDate: date,
                        entryPrice: entryPrice,
                        exitPrice: price,
                        quantity: shares,
                        type: .long,
                        exitReason: isTrailingHit ? "Trailing Stop" : (isTrendBroken ? "Trend Broken" : "Stop Loss")
                    )
                    trades.append(trade)
                    shares = 0
                    entryPrice = 0
                    maxTradeHigh = 0
                }
            }
            
            // Check Entries if cash
            else if shares == 0 {
                // BUY Signal
                if isBuySignal {
                    // BUY
                    let investAmount = capital * 0.99 // Keep 1% cash buffer
                    
                    let fee = investAmount * 0.001
                    let netInvest = investAmount - fee
                    
                    shares = netInvest / price
                    entryPrice = price
                    entryDate = date
                    maxTradeHigh = price // Init Trailing
                    capital -= investAmount
                }
            }
            
            // Update Equity Curve
            let currentVal = capital + (shares * price)
            equityCurve.append(EquityPoint(date: date, value: currentVal))
            
            // DD Calc
            if currentVal > maxEquity { maxEquity = currentVal }
            let dd = (maxEquity - currentVal) / maxEquity * 100
            if dd > maxDrawdown { maxDrawdown = dd }
        }
        
        // Close Open Position at end
        if shares > 0 {
            let last = sortedCandles.last!
            let revenue = shares * last.close
            capital += revenue
            
            let trade = BacktestTrade(
                entryDate: entryDate,
                exitDate: last.date,
                entryPrice: entryPrice,
                exitPrice: last.close,
                quantity: shares,
                type: .long,
                exitReason: "End of Sim"
            )
            trades.append(trade)
        }
        
        let totalReturn = ((capital - startCapital) / startCapital) * 100.0
        // Fix PNL isolation access by manual calc
        let wins = trades.filter { ($0.exitPrice - $0.entryPrice) * $0.quantity > 0 }.count
        let winRate = trades.isEmpty ? 0 : (Double(wins) / Double(trades.count)) * 100.0
        
        return BacktestResult(
            symbol: symbol,
            config: config,
            finalCapital: capital,
            totalReturn: totalReturn,
            trades: trades,
            winRate: winRate,
            candles: sortedCandles, // Pass sorted candles for visualization
            maxDrawdown: maxDrawdown,
            equityCurve: equityCurve,
            logs: []
        )
    }
    
    private func emptyResult(symbol: String, config: BacktestConfig) -> BacktestResult {
        return BacktestResult(
            symbol: symbol,
            config: config,
            finalCapital: config.initialCapital,
            totalReturn: 0,
            trades: [],
            winRate: 0,
            candles: [],
            maxDrawdown: 0,
            equityCurve: [],
            logs: []
        )
    }
}
