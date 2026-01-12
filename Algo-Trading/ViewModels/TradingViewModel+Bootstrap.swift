
import Foundation
import Combine
import SwiftUI

// MARK: - App Bootstrap Application Logic
extension TradingViewModel {
    
    /// Call this once on App launch. Idempotent.
    /// OPTIMIZED: Ağır işlemler geciktirildi, UI hemen açılıyor
    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        
        let startTime = Date()
        let signpost = SignpostLogger.shared
        let id = signpost.begin(log: signpost.startup, name: "BOOTSTRAP")
        
        // DEBUG dump KALDIRILDI - Performans için
        
        defer { 
            signpost.end(log: signpost.startup, name: "BOOTSTRAP", id: id) 
            let duration = Date().timeIntervalSince(startTime)
            print("🚀 BOOTSTRAP FINISHED in \(String(format: "%.3f", duration))s")
            Task { @MainActor in self.bootstrapDuration = duration }
        }
        
        // PHASE 1: HIZLI - UI'ı bloklamayan işlemler (~100ms hedef)
        // ---------------------------------------------------------
        
        // Load Persistent Data (Disk I/O - hızlı)
        loadWatchlist()
        loadPortfolio()
        loadTransactions()
        loadBalance()
        loadBistBalance()
        
        // BIST Bakiye Tutarlılık Kontrolü (Gerekirse düzelt, sıfırlama YAPMA)
        // Not: resetBistPortfolio() KALDIRILDI - bu debug koduydu ve her açılışta 
        // tüm BIST portföyünü sıfırlıyordu!
        // recalculateBistBalance() // Sadece tutarsızlık varsa bunu etkinleştir
        
        // Setup SSoT Bindings (Memory - hızlı)
        setupStoreBindings()
        
        print("🚀 Phase 1: UI Ready (persisted data loaded)")
        
        // PHASE 2: GECİKTİRİLMİŞ - Ağır işlemler background'da
        // ---------------------------------------------------------
        Task.detached(priority: .background) { [weak self] in
            // 2 saniye bekle - UI'ın render olmasına izin ver
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                guard let self = self else { return }
                
                // RL-Lite: Tune System based on history
                ArgusFeedbackLoopService.shared.tuneSystem(history: self.portfolio)
                
                // Enable Live Mode
                self.isLiveMode = true
                
                // Connect Stream for Watchlist
                print("🔌 Bootstrap Phase 2: Connecting Stream...")
                self.marketDataProvider.connectStream(symbols: self.watchlist)
            }
        }
        
        // PHASE 3: LAZY - Scout/AutoPilot loop'ları daha geç başlasın
        // ---------------------------------------------------------
        Task.detached(priority: .utility) { [weak self] in
            // 5 saniye bekle - Kullanıcı UI'ı görsün önce
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
            await MainActor.run {
                guard let self = self else { return }
                
                // Start Scout Loop
                print("🚀 Bootstrap Phase 3: Starting Scout Loop...")
                self.startScoutLoop()
                
                // Start Auto-Pilot Loop if enabled
                self.startAutoPilotLoop()
                
                // Start Watchlist Loop (Polling Backup)
                self.startWatchlistLoop()
            }
        }
        
        // PHASE 4: BACKGROUND - Atlas/Demeter (en ağır işlemler)
        // ---------------------------------------------------------
        Task.detached(priority: .background) { [weak self] in
            // 10 saniye bekle
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            
            guard let self = self else { return }
            
            print("🚀 Bootstrap Phase 4: Starting Atlas/Demeter...")
            await self.hydrateAtlas()
            await self.runDemeterAnalysis()
            
            // Quota Reset (artık acil değil)
            await QuotaLedger.shared.reset(provider: "Finnhub")
            await QuotaLedger.shared.reset(provider: "Yahoo")
            await QuotaLedger.shared.reset(provider: "Yahoo Finance")
        }
        
        print("🚀 TradingViewModel Bootstrap Queued (Lazy Loading Active)")
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
