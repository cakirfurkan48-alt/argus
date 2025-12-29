import Foundation
import SwiftUI
import Combine

// MARK: - AutoPilot & Trading Logic
extension TradingViewModel {

    // MARK: - Portfolio State Helper
    
    /// Converts portfolio array to dictionary format for AutoPilotEngine
    /// Uses first open position per symbol (duplicate-safe)
    func buildPortfolioState() -> [String: Trade] {
        var result: [String: Trade] = [:]
        for trade in portfolio where trade.isOpen {
            if result[trade.symbol] == nil {
                result[trade.symbol] = trade
            }
        }
        return result
    }

    // MARK: - Auto-Pilot Logic
    
    // MARK: - Auto-Pilot Logic
    
    func startAutoPilotLoop() {
        print("🤖 AutoPilot: Starting Loop...")
        autoPilotTimer?.invalidate()
        autoPilotTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.runAutoPilot()
            }
        }
    }
    
    func runAutoPilot() async {
        // Capture State on Main Thread to avoid racing
        let (symbols, currentPortfolio, currentBalance, currentEquity, enabled) = await MainActor.run {
             return (self.watchlist, self.portfolio, self.balance, self.getEquity(), self.isAutoPilotEnabled)
        }
        
        guard enabled else { return }
        
        // Duplicate-safe: keep first open position per symbol
        var portfolioMap: [String: Trade] = [:]
        for trade in currentPortfolio where trade.isOpen {
            if portfolioMap[trade.symbol] == nil {
                portfolioMap[trade.symbol] = trade
            }
        }
        
        // 1. Get Signals (Argus Engine) - Offload to Background
        let results = await Task.detached(priority: .userInitiated) {
            return await AutoPilotService.shared.scanMarket(
                symbols: symbols,
                equity: currentEquity,
                buyingPower: currentBalance,
                portfolio: portfolioMap
            )
        }.value
        
        let signals = results.signals
        let logs = results.logs
        
        if !signals.isEmpty || !logs.isEmpty {
            await MainActor.run {
                // Update UI Pipeline (Scouting Tab)
                self.scoutingCandidates = signals
                
                // Optimized Log Update (Cap at 100 to prevent Freezing)
                let combinedLogs = logs + self.scoutLogs
                self.scoutLogs = Array(combinedLogs.prefix(100))
                
                print("♻️ Watcher: Updated with \(logs.count) new logs. Total display: \(self.scoutLogs.count)")
                
                // NEW: Populate grandDecisions for each discovered signal (for Sanctum UI)
                Task {
                    for signal in signals where signal.action == .buy {
                        // Skip if we already have a decision for this symbol
                        guard self.grandDecisions[signal.symbol] == nil else { continue }
                        
                        // Get candles for Grand Council
                        guard let candles = self.candles[signal.symbol], candles.count >= 50 else { continue }
                        
                        // Convene the Grand Council
                        let macro = MacroSnapshot.fromCached() // FIX: Gerçek VIX verisi
                        
                        // Get Financials - simplified to nil for now due to type mismatch
                        // TODO: Fix FinancialSnapshot vs FinancialsData type inconsistency
                        let financials: FinancialsData? = nil
                        
                        // Get News Data - simplified to nil for now
                        // TODO: Properly integrate HermesCacheStore.shared when types are fixed
                        let newsData: HermesNewsSnapshot? = nil
                        
                        let decision = await ArgusGrandCouncil.shared.convene(
                            symbol: signal.symbol,
                            candles: candles,
                            financials: financials,
                            macro: macro,
                            news: newsData,
                            engine: .pulse
                        )
                        
                        await MainActor.run {
                            self.grandDecisions[signal.symbol] = decision
                        }
                        
                        print("🏛️ Scout: \(signal.symbol) için Grand Council kararı alındı: \(decision.action.rawValue)")
                    }
                }
                
                // CHIRON: EXECUTION GOVERNOR
                Task { @MainActor in
                    for signal in signals {
                        let currentPrice = self.quotes[signal.symbol]?.currentPrice ?? 0.0
                        guard currentPrice > 0 else { continue }
                        
                        if signal.action == .buy {
                            // Prevent piling up on same symbol
                            if self.portfolio.contains(where: { $0.symbol == signal.symbol && $0.isOpen }) {
                                continue
                            }
                            
                            // 2. Dynamic Sizing (10% of Balance)
                            let allocation = self.balance * 0.10
                            guard allocation >= 50.0 else { continue } // Min trade $50
                            let proposedQuantity = allocation / currentPrice
                            
                            // Get Fresh Scores for Governor
                            // Fix: Cache full Orion result for Argus Voice
                            let orionResult = OrionAnalysisService.shared.calculateOrionScore(
                                symbol: signal.symbol,
                                candles: self.candles[signal.symbol] ?? [],
                                spyCandles: self.candles["SPY"]
                            )
                            if let res = orionResult {
                                self.orionScores[signal.symbol] = res
                            }
                            
                            let scores = (
                                atlas: FundamentalScoreStore.shared.getScore(for: signal.symbol)?.totalScore,
                                orion: orionResult?.score,
                                aether: self.macroRating?.numericScore, 
                                hermes: nil as Double?
                            )
                            
                            // Construct AutoPilotSignal for Governor
                            // Determine engine from signal source (if available) or default
                            let signalEngine: AutoPilotEngine = signal.reason.lowercased().contains("corse") ? .corse : .pulse
                            
                            let apSignal = AutoPilotSignal(
                                action: signal.action,
                                quantity: proposedQuantity,
                                reason: signal.reason,
                                stopLoss: signal.stopLoss,
                                takeProfit: signal.takeProfit,
                                strategy: signalEngine,
                                trimPercentage: nil
                            )
                            
                            let decision = await ExecutionGovernor.shared.review(
                                signal: apSignal,
                                symbol: signal.symbol,
                                quantity: proposedQuantity,
                                portfolio: self.portfolio, // Fresh ref
                                equity: self.getEquity(),
                                scores: (scores.atlas, scores.orion, scores.aether, nil)
                            )
                            
                            switch decision {
                            case .approved(let finalSignal, let adjustedQty):
                                // CRITICAL FIX: Update Central Decision Store with FRESH reasons to avoid "Phantom Hold" logs
                                // We simulate a "BUY" decision for the records since Governor approved it.
                                // Fetch Phoenix for UI consistency
                                let pAdvice = await PhoenixScenarioEngine.shared.analyze(symbol: signal.symbol, timeframe: .h1)

                                let freshDecision = ArgusDecisionResult(
                                    symbol: signal.symbol,
                                    assetType: .stock,
                                    atlasScore: scores.atlas ?? 0,
                                    aetherScore: scores.aether ?? 0,
                                    orionScore: scores.orion ?? 0,
                                    athenaScore: 0,
                                    hermesScore: 0,
                                    cronosScore: 0,
                                    orionDetails: nil,
                                    chironResult: nil,
                                    phoenixAdvice: pAdvice,
                                    standardizedOutputs: [:],
                                    moduleWeights: nil, // UI Weights
                                    finalScoreCore: 85.0, // Forced High Score for Approved AutoPilot
                                    finalScorePulse: 0,
                                    letterGradeCore: "A",
                                    letterGradePulse: "-",
                                    finalActionCore: .buy, // ENSURE BUY
                                    finalActionPulse: .buy,
                                    isNewsBacked: false,
                                    isRegimeGood: (scores.aether ?? 0) > 50,
                                    isFundamentallyStrong: (scores.atlas ?? 0) > 50,
                                    isTimeAligned: true,
                                    generatedAt: Date()
                                )
                                self.argusDecisions[signal.symbol] = freshDecision
                                
                                // NEW: Sync with Sanctum UI (Grand Decision)
                                let grandDecision = ArgusGrandDecision(
                                    id: UUID(),
                                    symbol: signal.symbol,
                                    action: .aggressiveBuy, // AutoPilot Entry is always a committed Buy
                                    strength: .strong,
                                    confidence: 0.95,
                                    reasoning: "🤖 OTO PİLOT İŞLEMİ: \(signal.reason)",
                                    contributors: [
                                        ModuleContribution(module: "Orion", action: .buy, confidence: 0.9, reasoning: "AutoPilot Trigger"),
                                        ModuleContribution(module: "Chiron", action: .buy, confidence: 1.0, reasoning: "Governor Approved")
                                    ],
                                    vetoes: [],
                                    orionDecision: CouncilDecision(
                                        symbol: signal.symbol,
                                        action: .buy,
                                        netSupport: 0.9,
                                        approveWeight: 0.9,
                                        vetoWeight: 0.0,
                                        isStrongSignal: true,
                                        isWeakSignal: false,
                                        winningProposal: nil,
                                        allProposals: [],
                                        votes: [],
                                        vetoReasons: [],
                                        timestamp: Date()
                                    ),
                                    atlasDecision: nil,
                                    aetherDecision: AetherDecision(
                                        stance: .riskOn,
                                        marketMode: .greed,
                                        netSupport: 0.8,
                                        isStrongSignal: true,
                                        winningProposal: nil,
                                        votes: [],
                                        warnings: [],
                                        timestamp: Date()
                                    ),
                                    hermesDecision: nil,
                                    timestamp: Date()
                                )
                                self.grandDecisions[signal.symbol] = grandDecision
                                
                                // Execute Real Spot Buy - USE CORRECT ENGINE FROM SIGNAL
                                self.buy(
                                    symbol: signal.symbol,
                                    quantity: adjustedQty, // Use Adjusted
                                    source: .autoPilot,
                                    engine: signalEngine,  // FIX: Use correct engine (Corse or Pulse)
                                    stopLoss: finalSignal.stopLoss,
                                    takeProfit: finalSignal.takeProfit,
                                    rationale: "OTO ALIM (\(signalEngine.rawValue)): \(finalSignal.reason)" // Include engine in rationale
                                )
                                self.autoPilotLogs.append("🤖 OTO ALIM: \(signal.symbol) Başarılı. (\(finalSignal.reason))")
                                
                                // Notify Chiron Journal
                                let tradeRef = Trade(
                                    id: UUID(),
                                    symbol: signal.symbol,
                                    entryPrice: currentPrice,
                                    quantity: adjustedQty,
                                    entryDate: Date(),
                                    isOpen: true,
                                    engine: signalEngine, // FIX: Trade ownership
                                    stopLoss: finalSignal.stopLoss,
                                    takeProfit: finalSignal.takeProfit
                                )
                                await ExecutionGovernor.shared.didExecute(
                                    trade: tradeRef,
                                    scores: (scores.atlas ?? 0, scores.orion ?? 0, scores.aether ?? 0, 0, nil)
                                )
                                
                                // ARGUS VOICE: Proactive Report Generation
                                Task {
                                    let trace = DecisionTraceBuilder.build(
                                        symbol: signal.symbol,
                                        action: "BUY",
                                        fillPrice: currentPrice,
                                        quantity: adjustedQty,
                                        orion: self.orionScores[signal.symbol],
                                        atlas: FundamentalScoreStore.shared.getScore(for: signal.symbol),
                                        aether: self.macroRating,
                                        hermes: nil
                                    )
                                    await self.generateVoiceReport(for: signal.symbol, tradeId: tradeRef.id, existingTrace: trace)
                                }
                                
                            case .rejected(let reason):
                                print("🛑 Chiron Governor VETO: \(signal.symbol) -> \(reason)")
                                self.autoPilotLogs.append("🛡️ CHIRON RED: \(signal.symbol) engellendi. (\(reason))")
                            }

                            
                        } else if signal.action == .sell {
                            // Handle Sell Signal (Exit)
                            if let trade = self.portfolio.first(where: { $0.symbol == signal.symbol && $0.isOpen }) {
                                print("🤖 OTO SATIŞ: \(signal.symbol) -> \(signal.reason)")
                                
                                // Calculate Quantity (Full or Trim)
                                var quantityToSell: Double? = nil
                                if let trimPct = signal.trimPercentage {
                                    quantityToSell = trade.quantity * trimPct
                                }
                                
                                // FIX: Explicitly set source to .autoPilot to avoid "MANUAL" label
                                self.sell(tradeId: trade.id, currentPrice: currentPrice, quantity: quantityToSell, reason: signal.reason, source: .autoPilot)
                                
                                if let trim = signal.trimPercentage {
                                    self.autoPilotLogs.append("✂️ OTO AZALT: \(signal.symbol) %\(Int(trim * 100)) satıldı. (\(signal.reason))")
                                } else {
                                    self.autoPilotLogs.append("🤖 OTO SATIŞ: \(signal.symbol) kapatıldı. (\(signal.reason))")
                                }
                                
                                // Log Exit to Journal
                                await TradeJournal.shared.logExit(
                                    tradeId: trade.id,
                                    exitPrice: currentPrice,
                                    exitDate: Date(),
                                    exitReason: signal.reason
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - AGORA Execution Logic (Protected Trading)
    
    /// Merkezi işlem yürütücü. Sadece burası AutoPilot tarafından çağrılmalı.
    /// Amount: Notional Value ($) intended for the trade.
    func executeProtectedTrade(signal: TradeSignal, engineName: String, amount: Double) {
        let symbol = signal.symbol
        let action: TradeAction = (signal.action == .buy) ? .buy : .sell
        
        guard let quote = quotes[symbol] else { return }
        let currentPrice = quote.currentPrice
        
        // 1. Calculate Quantity (Strict Accounting)
        var quantity: Double = 0.0
        
        if action == .buy {
            // Amount from Signal implies "Notional Value" ($)
            // But we need to account for fee and exact qty.
             
            // Calculate hypothetical fee (approx 0.1%)
            let fee = amount * 0.001
            let netAmount = amount - fee
            quantity = netAmount / currentPrice
        } else {
            // Sell: Assume amount is NOTIONAL ($).
            quantity = amount / currentPrice
            
            // Limit to what we own (Dust protection)
            let owned = portfolio.filter { $0.symbol == symbol && $0.isOpen }.reduce(0) { $0 + $1.quantity }
            if quantity > owned {
                quantity = owned // Cap at max owned
            }
        }
        
        // 2. AGORA GOVERNANCE CHECK (V2)
        var decisionSnapshot: DecisionSnapshot?
        
        if let decision = argusDecisions[symbol] {
             let snapshot = AgoraExecutionGovernor.shared.audit(
                decision: decision,
                currentPrice: currentPrice,
                portfolio: portfolio,
                lastTradeTime: lastTradeTimes[symbol],
                lastActionPrice: nil
            )
            decisionSnapshot = snapshot
            
            if snapshot.locks.isLocked {
                print("🛑 AGORA BLOCKED SIGNAL: \(snapshot.reasonOneLiner)")
                // Log rejection
                self.agoraSnapshots.append(snapshot)
                return 
            }
        } else {
            // If no decision context exists, we rely on basic checks or allow?
            // "Kural 0": Don't change behavior. If we can't audit, maybe proceed? 
            // But we should try to protect.
            // For now, if no decision, we assume it's a manual or raw signal that bypasses Agora logic 
            // (or we simply lack the context to generate usage evidence).
            print("⚠️ Agora Audit Skipped: No Decision Context for \(symbol)")
        }

        // Build Export Snapshots
        let marketSnapshot = makeMarketSnapshot(for: symbol, currentPrice: currentPrice)
        let traceSnapshot = decisionSnapshot != nil ? makeDecisionTraceSnapshot(from: decisionSnapshot!, mode: "SIGNAL") : nil
        
        // 4. Act (Explicitly Approved if we got here)
        if action == .buy {
             buy(symbol: symbol, quantity: quantity, source: .autoPilot, engine: nil, decisionTrace: traceSnapshot, marketSnapshot: marketSnapshot)
        } else {
             sell(symbol: symbol, quantity: quantity, source: .autoPilot, engine: nil, decisionTrace: traceSnapshot, marketSnapshot: marketSnapshot)
        }
            
        // Update State
        lastTradeTimes[symbol] = Date()

    }
    
    // MARK: - Passive AutoPilot Scanner (NVDA Fix)
    // Scan high-scoring assets in Watchlist/Portfolio that might NOT have news but are Technical/Fundamental screaming buys.
    
    /// Public Handover for Scout -> AutoPilot
    func processHighConvictionCandidate(symbol: String, score: Double) async {
        guard isAutoPilotEnabled else { return }
        
        // Check if we already have a trade
        if portfolio.contains(where: { $0.symbol == symbol && $0.isOpen }) { return }
        
        guard let quote = quotes[symbol] else { return }
        
        print("🤖 AutoPilot: Processing Scout Handover: \(symbol) Score: \(Int(score))")
        
        // Consult Portfolio Manager (The Brain)
        // Construct Holdings Map
        var currentHoldings: [String: Double] = [:]
        for trade in portfolio where trade.isOpen {
            if let decision = argusDecisions[trade.symbol] {
                currentHoldings[trade.symbol] = decision.finalScoreCore
            } else {
                currentHoldings[trade.symbol] = 50.0
            }
        }
        
        let action = AutoPilotPortfolioManager.shared.evaluateOpportunity(
            newSymbol: symbol,
            newScore: score,
            cashBalance: self.balance,
            totalPortfolioValue: self.getEquity() + self.balance,
            holdings: currentHoldings
        )
        
        switch action {
        case .buy(_, _):
            // Proceed to standard Evaluation (Sizing etc)
            await triggerAutoPilotEvaluation(symbol: symbol, quote: quote, score: score, isSwap: false)
            
        case .swap(let sellSymbol, let buySymbol, let reason):
            print("♻️ AutoPilot SWAP Triggered: \(reason)")
            if let tradeToSell = portfolio.first(where: { $0.symbol == sellSymbol && $0.isOpen }) {
                 self.sell(symbol: sellSymbol, quantity: tradeToSell.quantity, source: .autoPilot)
                 await triggerAutoPilotEvaluation(symbol: buySymbol, quote: quote, score: score, isSwap: true)
            }
            
        case .hold(let reason):
            print("✋ AutoPilot Manager REJECTED \(symbol): \(reason)")
        
        case .sell(_, _): break
        }
    }
    
    func scanHighConvictionCandidates() async {
        guard isAutoPilotEnabled else { return }
        
        print("AutoPilot: Running Passive High-Conviction Scan...")
        
        let candidates = Set(watchlist + portfolio.map { $0.symbol })
        
        for symbol in candidates {
            // We need full data for this symbol
            // If data is missing, skip or lightweight load?
            // Assuming we have Argus data loaded by now or loop will be slow.
            
            guard let quote = quotes[symbol],
                  let decision = argusDecisions[symbol] else { continue }
            
            // UPDATE HIGH WATER MARK (For Trailing Stop)
            if var trade = portfolio.first(where: { $0.symbol == symbol && $0.isOpen }) {
                let currentHigh = trade.highWaterMark ?? trade.entryPrice
                if quote.currentPrice > currentHigh {
                    // Update Portfolio State (InMemory)
                    // Note: We need a way to persist this back to the main portfolio array.
                    // Since 'portfolioMap' is a local copy, we must update the main model.
                    // For efficiency, we just pass the updated HighWaterMark to the logic if possible,
                    // or ideally, update the trade model permanently.
                    Task { @MainActor in
                         self.updateTradeHighWaterMark(symbol: symbol, price: quote.currentPrice)
                    }
                    trade.highWaterMark = quote.currentPrice // Local update for evaluation below
                }
            }
            
            // Check if Score is High enough to warrant AutoPilot attention purely on Technicals/Fundamentals
            // Atlas + Orion + Aether > 80?
            let score = decision.finalScoreCore // or Pulse
            
                // Threshold: 80 (Shortlist) - Real Decision handled by Manager
                if score >= 85 { // Only look at Very High Quality for Passive Scan
                    // Check if we already have a trade
                    if portfolio.contains(where: { $0.symbol == symbol && $0.isOpen }) { continue }
                    
                    print("AutoPilot: Found High Conviction Candidate (Passive): \(symbol) Score: \(Int(score))")
                    
                    // PRE-CHECK: Consult Portfolio Manager (The Brain)
                    // Construct Holdings Map
                    var currentHoldings: [String: Double] = [:]
                    for trade in portfolio where trade.isOpen {
                        if let decision = argusDecisions[trade.symbol] {
                            currentHoldings[trade.symbol] = decision.finalScoreCore
                        } else {
                            // If no decision yet, assume neutral or re-fetch? Use 50 as safe fallback
                            currentHoldings[trade.symbol] = 50.0 
                        }
                    }
                    
                    let action = AutoPilotPortfolioManager.shared.evaluateOpportunity(
                        newSymbol: symbol,
                        newScore: score,
                        cashBalance: self.balance,
                        totalPortfolioValue: self.getEquity() + self.balance,
                        holdings: currentHoldings
                    )
                    
                    switch action {
                    case .buy(_, _):
                        // Proceed to standard Evaluation (Sizing etc)
                        await triggerAutoPilotEvaluation(symbol: symbol, quote: quote, score: score, isSwap: false)
                        
                    case .swap(let sellSymbol, let buySymbol, let reason):
                        print("♻️ AutoPilot SWAP Triggered: \(reason)")
                        // 1. Sell Worst
                        // ...
                        if let tradeToSell = portfolio.first(where: { $0.symbol == sellSymbol && $0.isOpen }) {
                             self.sell(symbol: sellSymbol, quantity: tradeToSell.quantity, source: .autoPilot)
                             // 2. Buy Best
                             await triggerAutoPilotEvaluation(symbol: buySymbol, quote: quote, score: score, isSwap: true)
                        }
                        
                    case .hold(let reason):
                        print("✋ AutoPilot Manager REJECTED \(symbol): \(reason)")
                    
                    case .sell(_, _): break // Should not happen in this logic flow
                    }
                }
            }
        }
    
    // Helper to run the engine (Common logic)
    func triggerAutoPilotEvaluation(symbol: String, quote: Quote, score: Double, isSwap: Bool) async {
         let candidatesCandles = candles[symbol]
         let aetherRating = MacroRegimeService.shared.getCachedRating()
         let atlasScore = FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore
         let techScore = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candidatesCandles ?? [], spyCandles: nil)?.score ?? 0
         let cronosScore = CronosTimeEngine.shared.calculateTimingScore(candles: candidatesCandles ?? [])
         
         let evaluation = await ArgusAutoPilotEngine.shared.evaluate(
             symbol: symbol,
             currentPrice: quote.currentPrice,
             equity: self.getEquity(),
             buyingPower: self.balance,
             portfolioState: self.buildPortfolioState(),
             candles: candidatesCandles,
             atlasScore: atlasScore,
             orionScore: techScore,
             aetherRating: aetherRating,
             hermesInsight: nil,
             argusFinalScore: score,
             cronosScore: cronosScore
         )
         
         if let validSignal = evaluation.signal, validSignal.action == SignalAction.buy {
             print("🚀 Argus Passive Buy: \(symbol)")
             await MainActor.run {
                 self.executeAutoPilotTrade(signal: validSignal, symbol: symbol, price: quote.currentPrice)
             }
         }
    }
    
    @MainActor
    private func executeAutoPilotTrade(signal: AutoPilotSignal, symbol: String, price: Double) {
        let quantity = signal.quantity
        guard quantity > 0 else { return }
        
        // FIX: Use strategy property from signal instead of parsing reason text
        let engine: AutoPilotEngine = signal.strategy
        
        // Delegate to central buy function which handles Commissions ($1.50) & Market Checks
        self.buy(symbol: symbol, quantity: quantity, source: .autoPilot, engine: engine)
        print("✅ Trade executed with engine: \(engine.rawValue)") 
    }
    
    @MainActor
    func analyzeDiscoveryCandidates(_ tickers: [String], source: NewsInsight) async {
        guard isAutoPilotEnabled else { return } // Use Bool check instead of missing Service instance checks
        
        // ANTI-BLOAT: Limit concurrent Hermes trades
        let openHermesTrades = portfolio.filter { $0.isOpen && $0.engine == .hermes }
        if openHermesTrades.count >= 5 {
            print("Argus Discovery: Max Hermes positions (5) reached. Skipping new candidates.")
            return
        }
        
        for ticker in tickers {
            let symbol = ticker.uppercased()
            // 1. Filter: Skip check if already in portfolio or recently checked
            if portfolio.contains(where: { $0.symbol == symbol && $0.isOpen }) { continue }
            // Skip if it's the article's main symbol (already analyzed)
            if symbol == source.symbol { continue }
            
            // 2. Fetch Data (On-Demand)
            do {
                // Fetch Quote
                let quoteVal = await MarketDataStore.shared.ensureQuote(symbol: symbol)
                guard let quote = quoteVal.value else { return }
                
                let candlesVal = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day")
                guard let candles = candlesVal.value else { return }
                await MainActor.run { self.candles[symbol] = candles }
                
                // 3. Run Decision Engine (Unified Brain)
                
                // Gather Context
                let aetherRating = MacroRegimeService.shared.getCachedRating()
                let atlasScore = FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore
                
                // Tech: Calculate Orion Score
                guard let orionResult = OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles, spyCandles: nil) else { continue }
                
                // Cronos: Calculate Timing Score directly (requires candles)
                let cronosScore = CronosTimeEngine.shared.calculateTimingScore(candles: candles)
                
                // Run AutoPilot Evaluation
                let evaluation = await ArgusAutoPilotEngine.shared.evaluate(
                    symbol: symbol,
                    currentPrice: quote.currentPrice,
                    equity: self.getEquity(),
                    buyingPower: self.balance,
                    portfolioState: self.buildPortfolioState(), // FIX: Pass real portfolio
                    candles: candles,
                    atlasScore: atlasScore,
                    orionScore: orionResult.score,
                    orionDetails: orionResult.components, // Pass logic details for Dip Hunter
                    aetherRating: aetherRating,
                    hermesInsight: source,
                    argusFinalScore: nil, // Let engine compute if needed, or approx
                    cronosScore: cronosScore
                )
                
                if let validSignal = evaluation.signal, validSignal.action == SignalAction.buy {
                    print("🚀 Argus Discovery Approved by \(validSignal.reason)")
                    
                    await MainActor.run {
                        self.executeAutoPilotTrade(signal: validSignal, symbol: symbol, price: quote.currentPrice)
                    }
                } else {
                    print("Argus Discovery: Hermes liked it, but AutoPilot rejected: \(symbol)")
                }
            }
        }
    }
    
    // Stub for safety if missing in this file (usually exists in AutoPilot section)
    func checkAutoPilotTriggers(quote: Quote) {
        // Logic to check open positions and close if hitting stops
        // Calling ArgusAutoPilot if available or local logic
        guard let symbol = quote.symbol else { return }
        guard let trade = portfolio.first(where: { $0.symbol == symbol && $0.isOpen }) else { return }
        
        // Stop Loss Check
        if let sl = trade.stopLoss, quote.currentPrice < sl {
             print("🚨 Auto-Pilot: Stop Loss Triggered for \(symbol)")
             Task {
                 await ArgusAutoPilot.shared.executeExit(trade: trade, reason: "Stop Loss Triggered")
             }
        }
    }
    
    @objc func handleAutoPilotIntent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let symbol = userInfo["symbol"] as? String,
              let actionString = userInfo["action"] as? String,
              let value = userInfo["value"] as? Double else { return }
        
        let action: TradeAction = (actionString == "BUY") ? .buy : .sell
        let signalAction: SignalAction = (action == .buy) ? .buy : .sell
        
        // Fix: TradeSignal init matching Models.swift
        let signal = TradeSignal(
            symbol: symbol,
            action: signalAction,
            reason: "AutoPilot Sniper Entry via Intent",
            confidence: 80.0,
            timestamp: Date(),
            stopLoss: nil,
            takeProfit: nil
        )
        
        // Pass amount separately
        self.executeProtectedTrade(signal: signal, engineName: "ArgusAutoPilot", amount: value)
    }
    
    // MARK: - Stop Loss & Take Profit Checks
    
    func checkStopLoss(for trade: Trade, currentPrice: Double) {
        guard let stopPrice = trade.stopLoss else { return }
        if currentPrice <= stopPrice {
            print("🚨 Auto-Pilot: Stop Loss Triggered for \(trade.symbol) at \(currentPrice) (Stop: \(stopPrice))")
            Task {
                await self.executeExit(trade: trade, reason: "Stop Loss Triggered", price: currentPrice)
            }
        }
    }

    func checkTakeProfit(for trade: Trade, currentPrice: Double) {
        guard let targetPrice = trade.takeProfit else { return }
        if currentPrice >= targetPrice {
            print("💰 Auto-Pilot: Take Profit Triggered for \(trade.symbol) at \(currentPrice) (Target: \(targetPrice))")
            Task {
                await self.executeExit(trade: trade, reason: "Take Profit Target Hit", price: currentPrice)
            }
        }
    }
    
    /// Helper to bridge exit logic
    @MainActor
    private func executeExit(trade: Trade, reason: String, price: Double) async {
        self.sell(tradeId: trade.id, currentPrice: price, reason: reason, source: .autoPilot)
        self.autoPilotLogs.append("🤖 OTO ÇIKIŞ: \(trade.symbol) - \(reason)")
    }
}
