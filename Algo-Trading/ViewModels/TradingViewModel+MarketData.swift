import Foundation
import SwiftUI
import Combine

// MARK: - Market Data Management
extension TradingViewModel {
    
    // MARK: - Chart Data Management
    func loadCandles(for symbol: String, timeframe: String) async {
        DispatchQueue.main.async { self.isLoading = true }
        
        // Heimdall Routing via Store (SSoT)
        // Store handles coalescing
        let dataValue = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: timeframe)
        
        await MainActor.run {
            if let data = dataValue.value {
                self.candles[symbol] = data
            }
            self.isLoading = false
                            
            // Update Data Health
            self.updateDataHealth(for: symbol) { health in
                // Candles imply both quotes and intraday/history availability
                health.technical = CoverageComponent.present(quality: 0.8)
                health.lastUpdated = Date()
            }
        }
    }
    
    // Helper for ETF Detection (SSoT Aware)
    // Note: private in extension may be file-private, need internal access if used elsewhere?
    // TradingViewModel extensions can access private members of original class if in same module? No.
    // They must be 'internal' or 'open'.
    func isETF(symbol: String) -> Bool {
        // 1. Known Major ETFs (Hardcoded for reliability)
        let knownETFs = Set([
            // US Market
            "SPY", "QQQ", "IWM", "DIA", "VOO", "VTI", "VEA", "VWO", "EFA", "EEM",
            "ARKK", "ARKG", "ARKW", "ARKF", "ARKQ",
            // Sector
            "XLK", "XLF", "XLE", "XLV", "XLI", "XLP", "XLY", "XLU", "XLB", "XLRE", "XLC",
            // Bond
            "BND", "TLT", "IEF", "SHY", "LQD", "HYG", "JNK", "AGG",
            // Commodity
            "GLD", "SLV", "IAU", "USO", "UNG", "DBC", "GSG",
            // Leveraged
            "TQQQ", "SQQQ", "SPXL", "SPXS", "UPRO", "SDS", "SSO",
            // International
            "EWZ", "EWJ", "EWG", "EWU", "EWC", "EWY", "FXI", "INDA", "MCHI",
            // Dividend
            "SCHD", "DVY", "VYM", "HDV", "VIG",
            // Thematic
            "SMH", "SOXX", "XBI", "IBB", "KWEB", "CIBR", "ICLN", "TAN", "JETS", "BITO",
            // Turkey
            "TUR"
        ])
        
        if knownETFs.contains(symbol) { return true }
        
        // 2. Check Fundamentals Store
        if let fund = MarketDataStore.shared.fundamentals[symbol]?.value, fund.isETF { return true }
        
        // 3. Check Quote Sector
        if let quote = MarketDataStore.shared.getQuote(for: symbol), let sec = quote.sector, sec.contains("ETF") { return true }
        
        // 4. Pattern match (symbols ending with common ETF patterns)
        let etfPatterns = ["-USD", "ETF"]
        for pattern in etfPatterns {
            if symbol.contains(pattern) { return true }
        }
        
        // Fallback: Not an ETF
        return false
    }
    
    // Watchlist Loop Logic
    func refreshWatchlistQuotes() async {
        await fetchQuotes()
    }
    
    func fetchQuotes() async {
        let startTime = Date()
        let spanId = SignpostLogger.shared.begin(log: SignpostLogger.shared.quotes, name: "BatchFetchQuotes")
        defer { 
            SignpostLogger.shared.end(log: SignpostLogger.shared.quotes, name: "BatchFetchQuotes", id: spanId)
            let duration = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async { self.lastBatchFetchDuration = duration }
        }
        let portfolioSymbols = portfolio.filter { $0.isOpen }.map { $0.symbol }
        let safeSymbols = SafeUniverseService.shared.universe.map { $0.symbol }
        // Include Discover Symbols in the loop
        let allSymbols = Array(Set(watchlist + portfolioSymbols + safeSymbols).union(discoverSymbols))
        
        guard !allSymbols.isEmpty else { return }
        
        // Don't set isLoading=true globally to avoid flickering if we have cached data
        // Only if empty quotes
        if quotes.isEmpty {
           await MainActor.run { self.isLoading = true }
        }
        
        do {
            // Already computed allSymbols above
            print("🛡️ Refactored: Batch Fetching \(allSymbols.count) symbols via Heimdall...")
            
            var collected: [String: Quote] = [:]
            
            // Fetch in Chunks to prevent "Request Storm" causing UI freeze
            let chunks = allSymbols.chunked(into: 8) // Process 8 symbols at a time
            
            for chunk in chunks {
                try await withThrowingTaskGroup(of: (String, Quote).self) { group in
                    for symbol in chunk {
                        group.addTask {
                            let q = try await HeimdallOrchestrator.shared.requestQuote(symbol: symbol)
                            return (symbol, q)
                        }
                    }
                    
                    for try await (sym, q) in group {
                        collected[sym] = q
                    }
                }
                // Small breather between chunks to let UI breathe if needed
                // await Task.yield() 
            }
            
            await MainActor.run {
                // Merge with existing so we don't lose data if partial fail
                for (k, v) in collected {
                    self.quotes[k] = v
                }
                self.isLoading = false
            }
        } catch {
             print("Watchlist Refresh Failed (Heimdall): \(error)")
             await MainActor.run { self.isLoading = false }
        }
    }
    
    // Helper for Single Fetch (UI View usage)
    func fetchQuote(for symbol: String) async {
        do {
            let quote = try await HeimdallOrchestrator.shared.requestQuote(symbol: symbol)
            await MainActor.run {
                self.quotes[symbol] = quote
            }
        } catch {
            print("Single Fetch Failed for \(symbol): \(error)")
        }
    }
    
    // MARK: - Watchlist Loop
    func startWatchlistLoop() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchQuotes()
            }
        }
        // Run once immediately
        Task { await fetchQuotes() }
    }
    
    internal func fetchCandles() async {
        let spanId = SignpostLogger.shared.begin(log: SignpostLogger.shared.candles, name: "FetchCandles")
        defer { SignpostLogger.shared.end(log: SignpostLogger.shared.candles, name: "FetchCandles", id: spanId) }

        let isMarketOpen = MarketSessionManager.shared.isMarketOpen()
        
        print("🟢🟢🟢 HEIMDALL: fetchCandles() called for \(watchlist.count) symbols")
        
        for symbol in watchlist {
            // Smart Fetching: Candles change even less frequently if day hasn't closed, 
            // but for intraday we want updates.
            if !shouldFetchData(for: symbol, type: "candle", isMarketOpen: isMarketOpen) {
                continue
            }
            
                // Rate Limit Protection: 0.5s delay between calls
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                // Request 400 candles for proper backtest support using Heimdall
                print("🛡️ Heimdall: Fetching candles for \(symbol)")
                do {
                    let candleData = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 400)
                    print("🛡️ Heimdall: Received \(candleData.count) candles for \(symbol)")
                    await MainActor.run {
                        self.candles[symbol] = candleData
                        self.lastFetchTime["\(symbol)_candle"] = Date()
                    }
                } catch {
                    print("⚠️ Heimdall: Candle fetch failed for \(symbol): \(error)")
                }
        }
    }
    
    private func shouldFetchData(for symbol: String, type: String, isMarketOpen: Bool) -> Bool {
        let key = "\(symbol)_\(type)"
        guard let lastTime = lastFetchTime[key] else { return true } // Never fetched
        
        let now = Date()
        let secondsSince = now.timeIntervalSince(lastTime)
        
        if isMarketOpen {
            // If market is open, fetch if > 60 seconds (Quote) or > 300 seconds (Candle)
            if type == "quote" { return secondsSince > 60 }
            if type == "candle" { return secondsSince > 300 }
        } else {
            // If market is closed
            // Only fetch if data is very old (e.g. > 12 hours) to capture late data
            // User Rule: "Gereksiz refresh yapma"
            if secondsSince < 12 * 3600 { return false }
        }
        
        return true
    }

    // MARK: - Macro Environment
    
    // UI için son güncelleme zamanı
    var lastMacroUpdate: Date? {
        return MacroRegimeService.shared.getLastUpdate()
    }
    
    func checkAndRefreshMacro() {
        let service = MacroRegimeService.shared
        let now = Date()
        
        // Helper logic: If > 12 hours or nil, refresh
        let last = service.getLastUpdate()
        let maxAgeHours = 12.0
        
        let shouldRefresh: Bool
        if let lastUpdate = last {
            shouldRefresh = now.timeIntervalSince(lastUpdate) > (maxAgeHours * 3600)
        } else {
            shouldRefresh = true
        }
        
        if shouldRefresh {
            print("🔄 Macro Data Stale (>12h). Refreshing...")
            loadMacroEnvironment()
        } else {
            print("✅ Macro Data Fresh. Using cache.")
            // Ensure we have the data in ViewModel even if we don't fetch new
            if macroRating == nil {
                if let cached = service.getCachedRating() {
                    self.macroRating = cached
                } else {
                    // Cache expired but service returned nil? Fetch.
                    loadMacroEnvironment()
                }
            }
        }
    }
    
    func loadMacroEnvironment() {
        print("DEBUG: loadMacroEnvironment called")
        Task {
            print("DEBUG: Starting computeMacroEnvironment (forceRefresh)...")
            // REFORM: Her zaman forceRefresh yap - eski 58 puan sorunu çözülsün
            let rating = await MacroRegimeService.shared.computeMacroEnvironment(forceRefresh: true)
            print("DEBUG: computeMacroEnvironment success: \(rating.letterGrade) (Score: \(Int(rating.numericScore)))")
            await MainActor.run {
                self.macroRating = rating
                self.syncWidgetData() // Update widget when macro data is ready
                self.objectWillChange.send() // Notify UI of update time change
            }
        }
    }
    
    func syncWidgetData() {
        // Widgets are currently disabled.
        // Logic removed to prevent background updates.
    }
    
    // MARK: - Discovery & Screener
    
    func refreshMarketPulse() async {
        self.isLoading = true
        
        // 1. Fetch Parallel
        // Gainers
        async let gainers = HeimdallOrchestrator.shared.requestScreener(type: .gainers, limit: 10)
        // Losers
        async let losers = HeimdallOrchestrator.shared.requestScreener(type: .losers, limit: 10)
        // Active
        async let active = HeimdallOrchestrator.shared.requestScreener(type: .mostActive, limit: 10)
        
        let (g, l, a) = await (try? gainers, try? losers, try? active) as? ([Quote]?, [Quote]?, [Quote]?) ?? (nil, nil, nil)
        
        await MainActor.run {
           if let gainers = g {
               self.topGainers = gainers.compactMap { q in
                   guard let s = q.symbol else { return nil }
                   var mQ = q; mQ.symbol = s
                   self.quotes[s] = mQ
                   return mQ
               }
           }
           
           if let losers = l {
               self.topLosers = losers.compactMap { q in
                   guard let s = q.symbol else { return nil }
                   var mQ = q; mQ.symbol = s
                   self.quotes[s] = mQ
                   return mQ
               }
           }
           
           if let active = a {
               self.mostActive = active.compactMap { q in
                   guard let s = q.symbol else { return nil }
                   var mQ = q; mQ.symbol = s
                   self.quotes[s] = mQ
                   return mQ
               }
           }
           
           self.isLoading = false
        }
    }
    
    func loadDiscoverData() {
        Task {
            // Run Pulse
            await refreshMarketPulse()
            
            // Run Radar Strategies
            // In a real app, we might run this lazily or here.
            // For now, imply Radar is computed on-fly in View or here.
            // Let's populate RadarFeed
            await MainActor.run {
                // Populate default radar feed (e.g. High Quality Momentum)
                let picks = self.getRadarPicks(strategy: .highQualityMomentum)
                self.radarFeed = picks.map { 
                    RadarItem(
                        id: UUID(),
                        bankName: "Algoritma: Momentum",
                        summary: "\($0) için güçlü Trend ve Kalite sinyali (Skor: 85+)",
                        sentiment: .positive,
                        url: "",
                        date: Date()
                    )
                }
            }
        }
    }
    
    func fetchTopLosers() async {
        print("📉 Fetching Top Losers (Heimdall)...")
        do {
            // Route through Heimdall Screener
            let losers = try await HeimdallOrchestrator.shared.requestScreener(type: .losers, limit: 10)
            print("📉 Fetched \(losers.count) losers.")
            await MainActor.run {
                self.topLosers = losers
            }
        } catch {
            print("⚠️ Fetch Top Losers Failed: \(error)")
        }
    }
    
    enum ArgusRadarStrategy: String, CaseIterable {
         case highQualityMomentum = "Yüksek Kalite & Trend"
         case aggressiveGrowth = "Agresif Büyüme"
         case qualityPullback = "Fırsat Bölgesi"
     }
     
     func getRadarPicks(strategy: ArgusRadarStrategy) -> [String] {
         // Use existing quotes & scores. Do NOT fetch new API data here.
         let allSymbols = quotes.keys 
         
         return allSymbols.filter { symbol in
             guard let quote = quotes[symbol] else { return false }
             let atlas = fundamentalScoreStore.getScore(for: symbol)?.totalScore ?? 50
             let orion = orionScores[symbol]?.score ?? 50
             
             switch strategy {
             case .highQualityMomentum:
                 return atlas >= 75 && orion >= 70
             case .aggressiveGrowth:
                 return orion >= 80 && (atlas >= 50 && atlas < 80)
             case .qualityPullback:
                 return atlas >= 80 && quote.percentChange < -2.0 && quote.percentChange > -15.0
             }
         }.sorted { s1, s2 in
             let sc1 = fundamentalScoreStore.getScore(for: s1)?.totalScore ?? 0
             let sc2 = fundamentalScoreStore.getScore(for: s2)?.totalScore ?? 0
             return sc1 > sc2
         }
     }
    
    struct ThemeBasket: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let symbols: [String]
    }
    
    func getThematicLists() -> [ThemeBasket] {
        return [
            ThemeBasket(name: "Yapay Zeka Liderleri", description: "Sektörü domine eden AI devleri.", symbols: ["NVDA", "MSFT", "GOOGL", "AMD", "SMH"]),
            ThemeBasket(name: "Savunma Sanayii", description: "Jeopolitik risk hedge'i.", symbols: ["LMT", "RTX", "NOC", "GD", "ITA"]),
            ThemeBasket(name: "Temettü Kralları", description: "Düzenli nakit akışı.", symbols: ["KO", "PG", "JNJ", "PEP", "SCHD"]),
            ThemeBasket(name: "Kripto & Blockchain", description: "Yüksek riskli dijital varlıklar.", symbols: ["COIN", "MSTR", "MARA", "RIOT", "BITO"])
        ]
    }
}
