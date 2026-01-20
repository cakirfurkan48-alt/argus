
import Foundation
import Combine
import SwiftUI

/// AutoPilot Store
/// Otonom ticaret döngüsünü (Loop), durumunu ve lojistiğini yöneten Singleton Store.
/// TradingViewModel'den tamamen ayrıştırılmış execution katmanı.
final class AutoPilotStore: ObservableObject {
    static let shared = AutoPilotStore()
    
    // MARK: - State
    @Published var isAutoPilotEnabled: Bool = false {
        didSet {
            handleAutoPilotStateChange()
            // Sync with Legacy ViewModel if needed, or UI binds to this directly
            ExecutionStateViewModel.shared.isAutoPilotEnabled = isAutoPilotEnabled
        }
    }
    
    @Published var scoutingCandidates: [TradeSignal] = []
    @Published var scoutLogs: [ScoutLog] = []
    
    // Internal Loop State
    private var autoPilotTimer: Timer?
    
    // Dependencies
    private let portfolioStore = PortfolioStore.shared
    // Accessing MarketDataStore via shared instance in logic
    
    private init() {
        // Restore state if persisted (Optional)
        self.isAutoPilotEnabled = ExecutionStateViewModel.shared.isAutoPilotEnabled
    }
    
    // MARK: - Loop Management
    
    func startAutoPilotLoop() {
        print("🤖 AutoPilotStore: Starting Loop...")
        startTimer()
    }
    
    func stopAutoPilotLoop() {
        print("🤖 AutoPilotStore: Stopping Loop...")
        autoPilotTimer?.invalidate()
        autoPilotTimer = nil
    }
    
    private func handleAutoPilotStateChange() {
        if isAutoPilotEnabled {
            startTimer()
        } else {
            stopAutoPilotLoop()
        }
    }
    
    private func startTimer() {
        autoPilotTimer?.invalidate()
        autoPilotTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.runAutoPilot()
            }
        }
        // Run immediately once
        Task {
            await runAutoPilot()
        }
    }
    
    // MARK: - Core Execution Logic
    
    func runAutoPilot() async {
        guard isAutoPilotEnabled else { return }
        
        let symbols = WatchlistStore.shared.items
        
        // Prepare Quotes Map
        let simpleQuotes = MarketDataStore.shared.liveQuotes
        
        // Snapshot Portfolio State safely
        let portfolio = portfolioStore.trades
        let balance = portfolioStore.globalBalance
        let bistBalance = portfolioStore.bistBalance
        let equity = portfolioStore.getGlobalEquity(quotes: simpleQuotes)
        let bistEquity = portfolioStore.getBistEquity(quotes: simpleQuotes)
        
        // Build Portfolio Map
        var portfolioMap: [String: Trade] = [:]
        for trade in portfolio where trade.isOpen {
            if portfolioMap[trade.symbol] == nil {
                portfolioMap[trade.symbol] = trade
            }
        }
        
        // 1. Get Signals (Argus Engine) - Offload to Background
        let results = await Task.detached(priority: .userInitiated) {
            return await AutoPilotService.shared.scanMarket(
                symbols: symbols,
                equity: equity,
                bistEquity: bistEquity,
                buyingPower: balance,
                bistBuyingPower: bistBalance,
                portfolio: portfolioMap
            )
        }.value
        
        let signals = results.signals
        let logs = results.logs
        
        if !signals.isEmpty || !logs.isEmpty {
            await MainActor.run {
                // Update UI State
                self.scoutingCandidates = signals
                
                let combinedLogs = logs + self.scoutLogs
                self.scoutLogs = Array(combinedLogs.prefix(100))
                
                print("♻️ AutoPilotStore: Updated with \(logs.count) new logs.")
                
                // Process Buy Signals -> Grand Council -> Executor
                self.processSignals(signals)
            }
        }
    }
    
    // MARK: - Intent and Discovery Handling
    
    func analyzeDiscoveryCandidates(_ tickers: [String], source: NewsInsight) async {
        // Simple forward pass to logic if needed, or implement full logic here.
        // For now, we print to show connected.
        print("🤖 AutoPilotStore: Discovery Analysis for \(tickers.count) candidates from \(source.headline)")
        // Implementation Todo: Move full logic from TVM if complex, or keep shim.
        // Given Phase C requires extraction, we should implement logic eventually.
        // For now, implementing basic loop to satisfy compilation of call from TVM
    }

    func handleAutoPilotIntent(_ notification: Notification) {
        // Basic Intent Handling (Stub)
        print("🤖 AutoPilotStore: Intent Received")
    }

    @MainActor
    private func processSignals(_ signals: [TradeSignal]) {
        Task {
            for signal in signals where signal.action == .buy {
                // Skip if decision exists
                if SignalStateViewModel.shared.grandDecisions[signal.symbol] != nil { continue }
                
                // BIST Check
                if signal.symbol.uppercased().hasSuffix(".IS") {
                    if !isBistMarketOpen() { continue }
                }
                
                // Get Data
                guard let candles = await MarketDataStore.shared.ensureCandles(symbol: signal.symbol, timeframe: "1day").value, !candles.isEmpty else {
                    continue
                }
                
                // Convene Grand Council
                let macro = MacroSnapshot.fromCached()
                
                // Prepare BIST Input if needed
                var sirkiyeInput: SirkiyeEngine.SirkiyeInput? = nil
                if signal.symbol.uppercased().hasSuffix(".IS") {
                     sirkiyeInput = await prepareSirkiyeInput(macro: macro)
                }
                
                let decision = await ArgusGrandCouncil.shared.convene(
                    symbol: signal.symbol,
                    candles: candles,
                    financials: nil,
                    macro: macro,
                    news: nil,
                    engine: .pulse,
                    sirkiyeInput: sirkiyeInput,
                    origin: "AUTOPILOT_STORE"
                )
                
                SignalStateViewModel.shared.grandDecisions[signal.symbol] = decision
                print("🏛️ AutoPilotStore: Grand Council Decision for \(signal.symbol): \(decision.action.rawValue)")
            }
            
            // Execute Decisions (Trade Brain)
            // Note: We need to access 'quotes'. MarketDataStore has them but TradeBrain might need a map.
             let simpleQuotes = MarketDataStore.shared.liveQuotes
             
             await TradeBrainExecutor.shared.evaluateDecisions(
                 decisions: SignalStateViewModel.shared.grandDecisions,
                 portfolio: self.portfolioStore.trades,
                 quotes: simpleQuotes,
                 balance: self.portfolioStore.globalBalance,
                 bistBalance: self.portfolioStore.bistBalance,
                 orionScores: [:], // TODO: Populate if needed
                 candles: [:] // TradeBrain logic might need updating to pull from Store if candles missing
             )
             
             // Check Plan Triggers
             await self.checkPlanTriggers()
        }
    }
    
    // MARK: - Helpers
    
    // MARK: - Helpers
    
    private func prepareSirkiyeInput(macro: MacroSnapshot) async -> SirkiyeEngine.SirkiyeInput? {
        let quotes = MarketDataStore.shared.liveQuotes
        guard let usdQuote = quotes["USD/TRY"] else { return nil }
        
        return SirkiyeEngine.SirkiyeInput(
            usdTry: usdQuote.currentPrice,
            usdTryPrevious: usdQuote.previousClose ?? usdQuote.currentPrice,
            dxy: 104.0,
            brentOil: 80.0,
            globalVix: macro.vix,
            newsSnapshot: nil,
            currentInflation: 45.0,
            policyRate: 50.0,
            xu100Change: nil,
            xu100Value: nil,
            goldPrice: nil
        )
    }
    
    private func isBistMarketOpen() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        // Simple Check: 10:00 - 18:00 TRT (UTC+3) -> 07:00 - 15:00 UTC approximately
        // Adjust for system time assuming timezone is correct
        return hour >= 10 && hour < 18
    }
    
    private func checkPlanTriggers() async {
        // Plan Monitoring Logic (Simplified)
        // Access TradingViewModel+PlanExecution equivalent
        // Ideally PlanExecutor should be a service.
    }
    
    // MARK: - Passive Scanner
    func processHighConvictionCandidate(symbol: String, score: Double) async {
         // Logic from TVM+AutoPilot
         guard isAutoPilotEnabled else { return }
         // ... (Logic to be migrated)
    }
}
