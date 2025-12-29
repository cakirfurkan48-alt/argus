
import Foundation
import Combine
import SwiftUI

// MARK: - App Bootstrap Application Logic
extension TradingViewModel {
    
    /// Call this once on App launch. Idempotent.
    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        
        let startTime = Date()
        let signpost = SignpostLogger.shared
        let id = signpost.begin(log: signpost.startup, name: "BOOTSTRAP")
        
        // DEBUG: Dump Keys for Data Rescue
        print("------- RESCUE_DUMP_START -------")
        for (key, val) in UserDefaults.standard.dictionaryRepresentation().sorted(by: { $0.key < $1.key }) {
            if key.lowercased().contains("watch") || key.lowercased().contains("portfolio") || key.lowercased().contains("symbol") {
                 print("RESCUE_KEY: \(key) | TYPE: \(type(of: val))")
            }
        }
        print("------- RESCUE_DUMP_END -------")
        defer { 
            signpost.end(log: signpost.startup, name: "BOOTSTRAP", id: id) 
            let duration = Date().timeIntervalSince(startTime)
            print("🚀 BOOTSTRAP FINISHED in \(String(format: "%.3f", duration))s")
            DispatchQueue.main.async { self.bootstrapDuration = duration }
        }
        
        // RL-Lite: Tune System based on history
        ArgusFeedbackLoopService.shared.tuneSystem(history: portfolio)
        
        // TEMP: Force Reset Quota to clear "Exhausted" state from previous session/bug
        Task {
            await QuotaLedger.shared.reset(provider: "Finnhub")
            await QuotaLedger.shared.reset(provider: "Yahoo")
            await QuotaLedger.shared.reset(provider: "Yahoo Finance")
            print("🔄 Quota Reset: Finnhub, Yahoo cleared")
        }
        
        // Start Auto-Pilot Loop if enabled
        startAutoPilotLoop()
        
        // Start Scout Loop (Always active to serve user)
        print("🚀 Bootstrap: startScoutLoop() ÇAĞRILIYOR...")
        startScoutLoop()
        print("🚀 Bootstrap: startScoutLoop() TAMAMLANDI")

        // Load Persistent Data
        loadWatchlist()
        loadPortfolio()
        loadTransactions()
        loadBalance()

        // 🔴 FIX: Enable Live Mode by Default to ensure "movement"
        self.isLiveMode = true
        
        // 🔴 FIX: Connect Stream Immediately for Watchlist
        print("🔌 Bootstrap: Connecting Stream for \(watchlist.count) symbols...")
        marketDataProvider.connectStream(symbols: self.watchlist)
        
        // Start Watchlist Loop (Polling Backup)
        startWatchlistLoop()
        
        // Hydrate Atlas Fundamentals (Background)
        Task { 
            await hydrateAtlas()
            print("🚀 Bootstrap: Triggering Demeter Sector Analysis...")
            await runDemeterAnalysis()
        }
        
        // Setup SSoT Bindings
        setupStoreBindings()
        
        print("🚀 TradingViewModel Bootstrapped")
    }
    

    
    // MARK: - Data Loading
    
    func loadData() {
        isLoading = true
        let spanId = SignpostLogger.shared.begin(log: SignpostLogger.shared.ui, name: "LoadData")
        
        Task {
             print("🚀 Starting Parallel Data Load...")
             
             // 1. High Priority: Prices (Watchlist + Safe Cards)
             // Run concurrently
             // 'fetchQuotes' already includes Safe Assets and Watchlist.
             async let quotesJob: () = fetchQuotes()
             
             // Wait for prices
             _ = await quotesJob
             
             // UI Unblock: Show prices immediately
             await MainActor.run { self.isLoading = false }
             
             // 2. Medium Priority: History (Candles)
             // This can take time (has rate limit delays)
             await fetchCandles()
             
             // 3. Low Priority: Intelligence (Signals, Macro, Discover)
             // These depend on Candles/Quotes
             
             async let aiJob: () = generateAISignals()
             async let macroJob: () = MainActor.run { loadMacroEnvironment() }
             async let discoverJob: () = MainActor.run { loadDiscoverData() }
             async let losersJob: () = fetchTopLosers()
             async let demeterJob: () = runDemeterAnalysis()
             
             _ = await (aiJob, macroJob, discoverJob, losersJob, demeterJob)
             
             SignpostLogger.shared.end(log: SignpostLogger.shared.ui, name: "LoadData", id: spanId)
        }
    }
}
