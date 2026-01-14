import Foundation
import Combine
import SwiftUI

class TradingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var watchlist: [String] = [] {
        didSet {
            saveWatchlist()
        }
    }
    
    // Discovery Lists
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var mostActive: [Quote] = []
    
    // Terminal Optimized Data Source
    @Published var terminalItems: [TerminalItem] = []
    
    func refreshTerminal() {
        let newItems = watchlist.map { symbol -> TerminalItem in
            let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
            let quote = quotes[symbol]
            let decision = grandDecisions[symbol]
            
            return TerminalItem(
                id: symbol,
                symbol: symbol,
                market: isBist ? .bist : .global,
                currency: isBist ? .TRY : .USD,
                price: quote?.currentPrice ?? 0.0,
                dayChangePercent: quote?.percentChange,
                orionScore: orionScores[symbol]?.score,
                atlasScore: getFundamentalScore(for: symbol)?.totalScore,
                councilScore: decision?.confidence,
                action: decision?.action ?? .neutral,
                dataQuality: dataHealthBySymbol[symbol]?.qualityScore ?? 0,
                forecast: prometheusForecastBySymbol[symbol]
            )
        }
        
        // Sadece değişiklik varsa güncelle (UI performansın için)
        if newItems != terminalItems {
            terminalItems = newItems
        }
    }
    
    @Published var quotes: [String: Quote] = [:]
    @Published var candles: [String: [Candle]] = [:]
    @Published var patterns: [String: [OrionChartPattern]] = [:] // Orion V3 Pattern Store
    @Published var portfolio: [Trade] = [] {
        didSet {
            savePortfolio()
        }
    }
    @Published var balance: Double = 100000.0 { // USD bakiyesi
        didSet {
            saveBalance()
        }
    }
    @Published var bistBalance: Double = 1000000.0 { // 1M TL BIST demo bakiyesi
        didSet {
            saveBistBalance()
        }
    }
    @Published var usdTryRate: Double = 35.0 // Varsayılan kur
    
    @Published var aiSignals: [AISignal] = []
    @Published var macroRating: MacroEnvironmentRating?
    @Published var poseidonWhaleScores: [String: WhaleScore] = [:] // Poseidon (Big Fish)
    
    // UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Argus ETF State
    @Published var etfSummaries: [String: ArgusEtfSummary] = [:]
    @Published var isLoadingEtf = false
    
    // Reports
    @Published var dailyReport: String?
    @Published var weeklyReport: String?
    
    // BIST Reports
    @Published var bistDailyReport: String?
    @Published var bistWeeklyReport: String?
    
    // Sirkiye Engine State (BIST Politik Atmosfer)
    @Published var bistAtmosphere: AetherDecision?
    @Published var bistAtmosphereLastUpdated: Date?
    
    // Auto-Pilot State
    @AppStorage("isAutoPilotEnabled") var isAutoPilotEnabled: Bool = false
    var autoPilotTimer: Timer?
    @Published var autoPilotLogs: [String] = [] 
    @Published var lastAction: String = "" // For UI feedback
    
    // Navigation State
    @Published var selectedSymbolForDetail: String? = nil
    
    func addToWatchlist(symbol: String) {
        if !watchlist.contains(symbol) {
            watchlist.append(symbol)
        }
    }
    @Published var transactionHistory: [Transaction] = [] {
        didSet {
            saveTransactions()
        }
    }
    @Published var scoutingCandidates: [TradeSignal] = [] // Opportunities found by Scout
    @Published var scoutLogs: [ScoutLog] = [] // Detailed logs of why trades were accepted/rejected
    
    // Trade Brain Plan Execution Alerts
    @Published var planAlerts: [TradeBrainAlert] = [] // Plan triggered notifications
    
    // AGORA (Execution Governor V2)
    @Published var agoraSnapshots: [DecisionSnapshot] = [] // History of decisions (Approved & Rejected)

    var lastTradeTimes: [String: Date] = [:] // Symbol -> Date
    
    // Universe Cache
    @Published var universeCache: [String: UniverseItem] = [:]

    @MainActor
    func fetchUniverseDetails(for symbol: String) async {
        // Access MainActor property on UniverseEngine
        // Since both are MainActor, this should work.
        if let item = UniverseEngine.shared.universe[symbol] {
            self.universeCache[symbol] = item
        }
    }
    
    // Orion SAR+TSI Lab State
    @Published var sarTsiBacktestResult: OrionSarTsiBacktestResult?
    @Published var isLoadingSarTsiBacktest: Bool = false
    @Published var sarTsiErrorMessage: String?
    
    // Overreaction Hunter Lab
    @Published var overreactionResult: OverreactionResult?
    
    // DEMETER (Sector Engine)
    @Published var demeterScores: [DemeterScore] = []
    @Published var demeterMatrix: CorrelationMatrix?
    @Published var isRunningDemeter: Bool = false
    @Published var activeShocks: [ShockFlag] = []
    
    // Argus Scout (Pre-Cognition)
    var scoutTimer: Timer?
    
    // Hermes / News State
    @Published var hermesSummaries: [String: [HermesSummary]] = [:] // Symbol -> Summaries
    @Published var hermesMode: HermesMode = .full 
    
    // Generic Backtest State
    @Published var activeBacktestResult: BacktestResult?
    @Published var isBacktesting: Bool = false 
    
    // Smart Data Fetching State
    var lastFetchTime: [String: Date] = [:]
    var discoverSymbols: Set<String> = [] // Track symbols active in Discover View
    var failedFundamentals: Set<String> = [] // Circuit Breaker for Atlas Fetches
    
    // Services
    let marketDataProvider = MarketDataProvider.shared
    let fundamentalScoreStore = FundamentalScoreStore.shared
    let aiSignalService = AISignalService.shared
    // private let tvSocket = TradingViewSocketService.shared // REMOVED
    // private var tvSubscription: AnyCancellable? // REMOVED
    
    // Sınırsız Pozisyon Modu (Limit Yok)
    @Published var isUnlimitedPositions = false {
        didSet {
            PortfolioRiskManager.shared.isUnlimitedPositionsEnabled = isUnlimitedPositions
            print("⚡️ Sınırsız Pozisyon Modu: \(isUnlimitedPositions ? "AÇIK" : "KAPALI")")
        }
    }
    
    // Live Mode
    @Published var isLiveMode = false {
        didSet {
            if isLiveMode {
                startLiveSession()
            } else {
                stopLiveSession()
            }
        }
    }
    

    
    // Search State
    
    // MARK: - Demeter Integration
    
    @MainActor
    func runDemeterAnalysis() async {
        self.isRunningDemeter = true
        await DemeterEngine.shared.analyze()
        
        let scores = await DemeterEngine.shared.sectorScores
        let matrix = await DemeterEngine.shared.correlationMatrix
        let shocks = await DemeterEngine.shared.activeShocks
        
        self.demeterScores = scores
        self.demeterMatrix = matrix
        self.activeShocks = shocks
        self.isRunningDemeter = false
    }
    
    func getDemeterMultipliers(for symbol: String) async -> (priority: Double, size: Double, cooldown: Bool) {
        return await DemeterEngine.shared.getMultipliers(for: symbol)
    }
    
    func getDemeterScore(for symbol: String) -> DemeterScore? {
        // Synchronous lookup from cached scores
        guard let sector = SectorMap.getSector(for: symbol) else { return nil }
        return demeterScores.first(where: { $0.sector == sector })
    }
    @Published var searchResults: [SearchResult] = []
    // @Published var topLosers: [(String, Quote)] = [] // Removed duplicate
    @Published var athenaResults: [String: AthenaFactorResult] = [:] // Added Athena State
    var searchTask: Task<Void, Never>?
    var isBootstrapped = false // Prevent double-work
    
    @Published var dataHealthBySymbol: [String: DataHealth] = [:] // Pillar 1: Data Health
    var cancellables = Set<AnyCancellable>() // Combine Subscriptions

    // Performance Metrics (Freeze Detective)
    @Published var bootstrapDuration: Double = 0.0
    @Published var lastBatchFetchDuration: Double = 0.0
    
    init() {
        // Init is now lightweight.
        loadWatchlist() // Ensure watchlist is ready immediately (Real Data)
        loadPortfolio()
        loadBalance()
        loadTransactions()
        setupStreamingObservation()
        
        // Ekonomik takvim beklenti hatırlatması kontrolü
        Task { @MainActor in
            EconomicCalendarService.shared.checkAndNotifyMissingExpectations()
        }
        
        setupTradeBrainObservers()
    }
    
    private func setupStreamingObservation() {
        // SINGLE SOURCE OF TRUTH: Bind directly to MarketDataStore
        // The Store handles "Session Baseline", "Merge Logic", and "Staleness".
        // We just display what the Store tells us.
        MarketDataStore.shared.$quotes
            .receive(on: RunLoop.main)
            .sink { [weak self] storeQuotes in
                guard let self = self else { return }
                
                // 1. Update UI State (Efficiently)
                // We map DataValue<Quote> -> Quote
                self.quotes = storeQuotes.compactMapValues { $0.value }
                
                // 2. Auto-Pilot Checks (Triggered by data updates)
                // We iterate only through open positions to check stop losses
                for trade in self.portfolio.filter({ $0.isOpen }) {
                    if let quote = self.quotes[trade.symbol] {
                        self.checkStopLoss(for: trade, currentPrice: quote.currentPrice)
                        self.checkTakeProfit(for: trade, currentPrice: quote.currentPrice)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Trade Brain Execution Handlers
    
    private func setupTradeBrainObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTradeBrainBuy(_:)), name: .tradeBrainBuyOrder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTradeBrainSell(_:)), name: .tradeBrainSellOrder, object: nil)
    }
    
    @objc private func handleTradeBrainBuy(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let symbol = userInfo["symbol"] as? String,
              let quantity = userInfo["quantity"] as? Double,
              let price = userInfo["price"] as? Double else { return }
        
        Task { @MainActor in
            // 1. İşlemi Gerçekleştir
            self.buy(
                symbol: symbol,
                quantity: quantity,
                source: .autoPilot,
                engine: .pulse,
                stopLoss: nil,
                takeProfit: nil,
                rationale: "Trade Brain Execution"
            )
            
            // 2. Log (Basit bildirim)
            print("✅ TRADE BRAIN ALIM: \(symbol) - \(Int(quantity)) adet @ \(String(format: "%.2f", price))")
        }
    }
    
    @objc private func handleTradeBrainSell(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let _ = userInfo["price"] as? Double,
              let reason = userInfo["reason"] as? String else { return }
        
        if let tradeIdStr = userInfo["tradeId"] as? String,
           let tradeId = UUID(uuidString: tradeIdStr),
           let trade = self.portfolio.first(where: { $0.id == tradeId }) {
            
            Task { @MainActor in
                // 1. İşlemi Gerçekleştir
                self.sell(
                    tradeId: tradeId,
                    currentPrice: self.quotes[trade.symbol]?.currentPrice ?? 0,
                    reason: reason,
                    source: .autoPilot
                )
                
                // 2. Log
                print("🚨 TRADE BRAIN SATIŞ: \(trade.symbol) - \(reason)")
            }
        }
    }
    
    /// Call this once on App launch. Idempotent.


// MARK: - Chart Data Management
    // loadCandles moved to TradingViewModel+MarketData.swift
    
    // Helper for ETF Detection (SSoT Aware)
    // isETF moved to TradingViewModel+MarketData.swift
// MARK: - Hermes Integration
    
    func loadHermes(for symbol: String) async {
        // 1. Fetch Raw News
        let articles = await fetchRawNews(for: symbol)
        
        // 2. Process with HermesCoordinator
        let summaries = await HermesCoordinator.shared.processNews(articles: articles, allowAI: false)
        
        // 3. Update both old and new data stores
        await MainActor.run {
            self.hermesSummaries[symbol] = summaries
            self.hermesMode = HermesCoordinator.shared.getCurrentMode()
            
            // Also update newsInsightsBySymbol for backward compatibility
            self.newsInsightsBySymbol[symbol] = summaries.map { summary in
                // Derive sentiment from score
                let derivedSentiment: NewsSentiment
                if summary.impactScore >= 75 { derivedSentiment = .strongPositive }
                else if summary.impactScore >= 60 { derivedSentiment = .weakPositive }
                else if summary.impactScore <= 25 { derivedSentiment = .strongNegative }
                else if summary.impactScore <= 40 { derivedSentiment = .weakNegative }
                else { derivedSentiment = .neutral }
                
                return NewsInsight(
                    id: UUID(),
                    symbol: symbol,
                    articleId: summary.id,
                    headline: summary.summaryTR, 
                    summaryTRLong: summary.summaryTR,
                    impactSentenceTR: summary.impactCommentTR,
                    sentiment: derivedSentiment,
                    confidence: 0.9,
                    impactScore: Double(summary.impactScore),
                    relatedTickers: nil,
                    createdAt: summary.createdAt
                )
            }
        }
    }
    
    // Helper to bridge existing provider to Hermes
    private func fetchRawNews(for symbol: String) async -> [NewsArticle] {
        // Fallback to simple provider call
        // Using AggregatedNewsService (Legacy) directly as Hermes isn't fully SSoT yet
        return (try? await AggregatedNewsService.shared.fetchNews(symbol: symbol, limit: 10)) ?? []
    }
    
    deinit {
        // Timer cleanup - memory leak prevention
        stopAutoPilotTimer()
        scoutTimer?.invalidate()
        scoutTimer = nil
        
        // Combine subscriptions cleanup
        cancellables.removeAll()
        
        print("🧹 TradingViewModel deinit - all resources cleaned up")
    }
    

    
    func stopAutoPilotTimer() {
        autoPilotTimer?.invalidate()
        autoPilotTimer = nil
    }
    
    // MARK: - Data Export (For AI Analysis)
    func exportTransactionHistoryJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(transactionHistory)
            return String(data: data, encoding: .utf8) ?? "Hata: Veri kodlanamadı."
        } catch {
            return "Hata: \(error.localizedDescription)"
        }
    }
    
    // methods moved to extensions
    
    // MARK: - Safe Universe Fetching
    // Removed redundant fetchSafeAssets() as fetchQuotes() handles all relevant symbols including Safe Universe.
    

    
    // Market Data methods moved to TradingViewModel+MarketData.swift
    
    // MARK: - Widget Integration (New)
    

    
    private func calculateUnrealizedPnLPercent() -> Double {
        // Real implementation requires tracking "Equity at midnight"
        // For now, returning Total Unrealized PnL %
        guard balance > 0 else { return 0.0 }
        return getUnrealizedPnL() / balance * 100
    }
    

    
    private func calculateWinRate() -> Double {
        let closedTrades = portfolio.filter { !$0.isOpen && $0.source == .autoPilot }
        guard !closedTrades.isEmpty else { return 0.0 }
        let wins = closedTrades.filter { $0.profit > 0 }.count
        return Double(wins) / Double(closedTrades.count) * 100.0
    }
    
    // MARK: - Orion Score Integration
    
    @Published var orionScores: [String: OrionScoreResult] = [:]
    @Published var prometheusForecastBySymbol: [String: PrometheusForecast] = [:] // Prometheus 5-day forecasts
    
    // Orion Logic moved to TradingViewModel+Argus.swift
    
    // MARK: - Fundamental Score
    
    func getFundamentalScore(for symbol: String) -> FundamentalScoreResult? {
        return fundamentalScoreStore.getScore(for: symbol)
    }
    
    /// Helper to create FinancialSnapshot for Atlas Council from Cached Scores
    func getFinancialSnapshot(for symbol: String) -> FinancialSnapshot? {
        // Raw veriyi compositeScores içindeki FundamentalScoreResult'tan alıyoruz
        // Eğer compositeScores içinde yoksa store'a bak
        let score = compositeScores[symbol] ?? fundamentalScoreStore.getScore(for: symbol)
        guard let data = score?.financials else { return nil }
        
        let price = quotes[symbol]?.currentPrice ?? 0
        
        // Helper calculations
        var netMargin: Double? = nil
        if let ni = data.netIncome, let rev = data.totalRevenue, rev > 0 {
            netMargin = (ni / rev) * 100
        }
        
        var roe: Double? = nil
        if let ni = data.netIncome, let equity = data.totalShareholderEquity, equity > 0 {
            roe = (ni / equity) * 100
        }
        
        var debtToEquity: Double? = nil
        if let equity = data.totalShareholderEquity, equity > 0 {
             let totalDebt = (data.shortTermDebt ?? 0) + (data.longTermDebt ?? 0)
             debtToEquity = totalDebt / equity
        }

        return FinancialSnapshot(
            symbol: symbol,
            marketCap: data.marketCap,
            price: price,
            peRatio: data.peRatio,
            forwardPE: data.forwardPERatio,
            pbRatio: data.priceToBook,
            psRatio: nil,
            evToEbitda: data.evToEbitda,
            revenueGrowth: data.forwardGrowthEstimate,
            earningsGrowth: nil,
            epsGrowth: nil,
            roe: roe,
            roa: nil,
            debtToEquity: debtToEquity,
            currentRatio: nil,
            grossMargin: nil,
            operatingMargin: nil,
            netMargin: netMargin,
            dividendYield: data.dividendYield,
            payoutRatio: nil,
            dividendGrowth: nil,
            beta: nil,
            sharesOutstanding: nil,
            floatShares: nil,
            insiderOwnership: nil,
            institutionalOwnership: nil,
            sectorPE: nil,
            sectorPB: nil,
            targetMeanPrice: nil,
            targetHighPrice: nil,
            targetLowPrice: nil,
            recommendationMean: nil,
            analystCount: nil
        )
    }
    @Published var argusDecisions: [String: ArgusDecisionResult] = [:]
    @Published var grandDecisions: [String: ArgusGrandDecision] = [:] // NEW: Grand Council Decisions
    @Published var agoraTraces: [String: AgoraTrace] = [:] // AGORA V2 TRACE STORE
    @Published var argusExplanations: [String: ArgusExplanation] = [:]
    
    // MARK: - Argus Voice (New Reporting Layer)
    @Published var voiceReports: [String: String] = [:] // Symbol -> Report Text
    @Published var isGeneratingVoiceReport: Bool = false
    
    // Voice Report Logic moved to TradingViewModel+Argus.swift
    
    // MARK: - ETF Logic
    
    // MARK: - AGORA Execution Logic (Protected Trading)
    
    /// Merkezi işlem yürütücü. Sadece burası AutoPilot tarafından çağrılmalı.
    // MARK: - AGORA Execution Logic (Protected Trading)
    
    /// Merkezi işlem yürütücü. Sadece burası AutoPilot tarafından çağrılmalı.
    /// Amount: Notional Value ($) intended for the trade.
    // AutoPilot & Etf Methods moved to extensions

    @Published var isLoadingArgus: Bool = false
    
    // Argus Lab (Performance Tracking)
    @Published var argusLabStats: UnifiedAlgoStats?

    
    // MARK: - Smart Asset Detection
    // Argus Helpers moved to TradingViewModel+Argus.swift

    @MainActor
    // loadArgusData moved to TradingViewModel+Argus.swift
    
    // Retry AI Explanation (for 429 errors)

    
    // MARK: - Widget Integration
    
    // persistToWidget moved to TradingViewModel+Argus.swift
    

    

    
    func getTopPicks() -> [FundamentalScoreResult] {
        // Store'daki tüm skorları tara ve 70 üzeri olanları döndür
        // FundamentalScoreStore'a erişim lazım, o da private dictionary tutuyor olabilir.
        // Store'a getAllScores eklemek gerekebilir ama şimdilik watchlist üzerinden gidelim.
        
        var picks: [FundamentalScoreResult] = []
        for symbol in watchlist {
            if let score = fundamentalScoreStore.getScore(for: symbol), score.totalScore >= 70 {
                picks.append(score)
            }
        }
        return picks.sorted { $0.totalScore > $1.totalScore }
    }
    
    // MARK: - Data Health Helper (Pillar 1)
    
    func updateDataHealth(for symbol: String, update: (inout DataHealth) -> Void) {
        var health = dataHealthBySymbol[symbol] ?? DataHealth(symbol: symbol)
        update(&health)
        dataHealthBySymbol[symbol] = health
    }
    
    // MARK: - Terminal Bootstrap (Fetches data and updates health for all watchlist)
    func bootstrapTerminalData() async {
        // 0. Ensure macro data is loaded first (for 100% quality)
        _ = await MacroRegimeService.shared.evaluate()
        
        let symbols = watchlist // No limit - analyze all
        
        for symbol in symbols {
            // FIX: Quote (fiyat) verisini önce çek!
            if quotes[symbol] == nil {
                let val = await MarketDataStore.shared.ensureQuote(symbol: symbol)
                if let q = val.value {
                    await MainActor.run { self.quotes[symbol] = q }
                }
            }
            
            // FULL ANALYSIS: Use the same loadArgusData as detail view for consistency
            // This is slower but ensures Terminal and Detail show the same decision
            if grandDecisions[symbol] == nil {
                await loadArgusData(for: symbol)
            }
            
            // PROMETHEUS: 5-day price forecast
            // Ensure forecast exists or is generated
            if prometheusForecastBySymbol[symbol] == nil {
                // 1. Ensure Candles (Data Dependency)
                if candles[symbol] == nil {
                    let cVal = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day")
                    if let c = cVal.value {
                        await MainActor.run { self.candles[symbol] = c }
                    }
                }
                
                // 2. Generate Forecast if enough data
                if let candleData = candles[symbol], candleData.count >= 30 {
                    // Prices are usually oldest-first coming from provider.
                    // Prometheus expects newest-first.
                    let prices = candleData.map { $0.close }.reversed()
                    let forecast = await PrometheusEngine.shared.forecast(symbol: symbol, historicalPrices: Array(prices))
                    await MainActor.run { self.prometheusForecastBySymbol[symbol] = forecast }
                }
            }
            
            // 5. Update DataHealth based on ACTUAL data availability
            await MainActor.run {
                let candleCount = self.candles[symbol]?.count ?? 0
                let hasQuote = self.quotes[symbol] != nil
                let hasOrion = self.orionScores[symbol] != nil
                let hasFund = self.getFundamentalScore(for: symbol) != nil
                let hasCouncil = self.grandDecisions[symbol] != nil
                
                // Technical: Full quality if we have enough data
                let techQuality = (hasQuote || candleCount > 0) ? 1.0 : 0.0
                
                // Fundamental: Full quality if Atlas calculated
                let fundQuality = hasFund ? 1.0 : 0.0
                
                // Macro: Check if MacroRegimeService has cached data
                let hasMacro = MacroRegimeService.shared.getCachedRating() != nil
                let macroQuality = hasMacro ? 1.0 : 0.0
                
                // News: Check if we have news for this symbol
                let hasNews = !(self.newsInsightsBySymbol[symbol]?.isEmpty ?? true)
                let newsQuality = hasNews ? 1.0 : 0.5 // Partial if no specific news
                
                let health = DataHealth(
                    symbol: symbol,
                    lastUpdated: Date(),
                    fundamental: CoverageComponent(available: hasFund, quality: fundQuality),
                    technical: CoverageComponent(available: hasQuote || candleCount > 0, quality: techQuality),
                    macro: CoverageComponent(available: hasMacro, quality: macroQuality),
                    news: CoverageComponent(available: true, quality: newsQuality)
                )
                self.dataHealthBySymbol[symbol] = health
            }
        }
    }

    // MARK: - Portfolio Management
    
    func addSymbol(_ symbol: String) {
        let upper = symbol.uppercased()
        if !watchlist.contains(upper) {
            watchlist.append(upper)
            // Tüm veriyi yeniden çekmek yerine sadece yeni sembolü çekelim
            Task {
                await fetchSingleSymbolData(symbol: upper)
            }
        }
    }
    
    private func fetchSingleSymbolData(symbol: String) async {
        await MainActor.run { self.isLoading = true }
        
        // 1. Quote
        let val = await MarketDataStore.shared.ensureQuote(symbol: symbol)
        if let q = val.value {
            await MainActor.run {
                self.quotes[symbol] = q
            }
        }
        // Fetch Candles
        // Fetch 400 days to ensure enough history for Backtesting (Orion requires 60+ lookback)
        let cVal = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day")
        if let c = cVal.value {
            await MainActor.run { candles[symbol] = c }
        }
        // 3. AI Signals (Sadece bu sembol için güncellemek zor, hepsini yenilemek gerekebilir ama şimdilik pas geçelim veya optimize edelim)
        // await generateAISignals() // Sinyalleri şimdilik yormayalım.
        
        // 4. Atlas Fundamentals (Heimdall 6.4 Resurrection)
        // Background fetch to avoid blocking UI significantly, but ensure data flow.
        Task {
            await calculateFundamentalScore(for: symbol)
        }
        
        await MainActor.run { self.isLoading = false }
    }
    
    func removeSymbol(at offsets: IndexSet) {
        watchlist.remove(atOffsets: offsets)
    }
    

    
    // MARK: - Search
    
    func search(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            // Debounce (0.5 sn bekle)
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            
            print("🔍 ViewModel: Searching for '\(query)'")
            
            do {
                let results = try await marketDataProvider.searchSymbols(query: query)
                await MainActor.run {
                    print("🔍 ViewModel: Found \(results.count) results")
                    self.searchResults = results
                }
            } catch {
                print("Search error: \(error)")
            }
        }
    }
    
    // MARK: - Trading Logic
    
    /// BIST Piyasa Açıklık Kontrolü (Hafta içi 10:00 - 18:10)
    func isBistMarketOpen() -> Bool {
        // Eğer manuel override varsa (test için) buraya eklenebilir.
        let calendar = Calendar.current
        var now = Date()
        
        // TimeZone ayarı (Türkiye Saati - GMT+3)
        // Eğer sunucu saati zaten doğruysa gerek yok, ama garanti olsun
        // Basitlik için yerel saat kullanıyoruz (Kullanıcı TR'de varsayılıyor)
        
        // 1. Gün Kontrolü (Pazar=1, Cmt=7)
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 {
            // print("🛑 BIST Kapalı: Haftasonu")
            return false
        }
        
        // 2. Saat Kontrolü (10:00 - 18:10)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = hour * 60 + minute
        
        let startMinutes = 10 * 60 // 10:00
        let endMinutes = 18 * 60 + 10 // 18:10
        
        if totalMinutes >= startMinutes && totalMinutes < endMinutes {
            return true
        } else {
            // print("🛑 BIST Kapalı: Seans Dışı (\(hour):\(minute))")
            return false
        }
    }
        
    @MainActor
    func buy(symbol: String, quantity: Double, source: TradeSource = .user, engine: AutoPilotEngine? = nil, stopLoss: Double? = nil, takeProfit: Double? = nil, rationale: String? = nil, decisionTrace: DecisionTraceSnapshot? = nil, marketSnapshot: MarketSnapshot? = nil) {
        
        // UNIFIED INPUT VALIDATION & CURRENCY DETECTION
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        let currency: Currency = isBist ? .TRY : .USD
        let availableBalance = (currency == .TRY) ? bistBalance : balance
        
        let price = quotes[symbol]?.currentPrice
        
        // Validator'a isBist boolean'ı currency kontrolü için yine lazım
        let validation = TradeValidator.validateBuy(
            symbol: symbol,
            quantity: quantity,
            price: price,
            availableBalance: availableBalance,
            isBistMarketOpen: isBistMarketOpen(),
            isGlobalMarketOpen: MarketStatusService.shared.canTrade()
        )
        
        guard validation.isValid else {
            let errorMessage = validation.error?.localizedDescription ?? "Bilinmeyen hata"
            print("🛑 İŞLEM REDDEDİLDİ: \(errorMessage)")
            self.lastAction = "🛑 \(errorMessage)"
            return
        }
        
        // Price now guaranteed to be valid
        let validPrice = price!
        
        // AGORA GUARDRAIL (Decision V2)
        // ----------------------------------------------------------------
        if let decision = argusDecisions[symbol] {
            let snapshot = AgoraExecutionGovernor.shared.audit(
                decision: decision,
                currentPrice: validPrice,
                portfolio: portfolio,
                lastTradeTime: lastTradeTimes[symbol],
                lastActionPrice: nil
            )
            
            // Check Lock
            if snapshot.locks.isLocked {
                print("🛑 AGORA BLOCKED BUY: \(snapshot.reasonOneLiner)")
                self.lastAction = "⚠️ İşlem Engellendi: \(snapshot.reasonOneLiner)"
                self.agoraSnapshots.append(snapshot) // Log the rejection
                return // ABORT TRADE
            }
        }
        // ----------------------------------------------------------------
        
        let cost = quantity * validPrice
        let commission = FeeModel.shared.calculate(amount: cost)
        let totalCost = cost + commission
        
        // Bakiye kontrolü ve düşümü (Currency-Safe)
        if availableBalance >= totalCost {
            if currency == .TRY {
                bistBalance -= totalCost
            } else {
                balance -= totalCost
            }
            
            let newTrade = Trade(
                id: UUID(),
                symbol: symbol,
                entryPrice: validPrice,
                quantity: quantity,
                entryDate: Date(),
                isOpen: true,
                source: source,
                engine: engine,
                stopLoss: stopLoss,
                takeProfit: takeProfit,
                rationale: source == .autoPilot ? (rationale ?? "BUY_SIGNAL") : "MANUAL_OVERRIDE",
                decisionContext: decisionTrace != nil ? makeDecisionContext(fromTrace: decisionTrace!) : (decisionTrace != nil && !self.agoraSnapshots.isEmpty ? makeDecisionContext(from: self.agoraSnapshots.last!) : nil),
                currency: currency // Explicit Currency
            )
            portfolio.append(newTrade)
            
            // Build Execution Snapshot
            let execution = ExecutionSnapshot(
                orderType: "MARKET",
                requestedPrice: validPrice,
                filledPrice: validPrice,
                slippagePct: 0.0,
                latencyMs: 15.0, // Simulated
                partialFill: false,
                requestedQty: quantity,
                filledQty: quantity,
                venue: "SIMULATION"
            )
            
            // Build Position Snapshot (Post-Trade)
            let posSnapshot = PositionSnapshot(
                positionQtyBefore: 0, // Simplified
                positionQtyAfter: quantity,
                avgCostBefore: 0,
                avgCostAfter: validPrice,
                holdingSeconds: 0,
                unrealizedPnlBefore: 0,
                realizedPnlThisTrade: 0,
                portfolioSnapshot: PositionSnapshot.PortfolioSnapshot(
                    cashBefore: (currency == .TRY ? bistBalance + totalCost : balance + totalCost),
                    cashAfter: (currency == .TRY ? bistBalance : balance),
                    grossExposure: portfolio.filter { $0.isOpen }.reduce(0) { $0 + ($1.quantity * (quotes[$1.symbol]?.currentPrice ?? $1.entryPrice)) },
                    netExposure: portfolio.filter { $0.isOpen }.reduce(0) { $0 + ($1.quantity * (quotes[$1.symbol]?.currentPrice ?? $1.entryPrice)) },
                    positionsCount: portfolio.filter { $0.isOpen }.count
                )
            )
            
            // Log History
            transactionHistory.append(Transaction(
                id: UUID(),
                type: .buy,
                symbol: symbol,
                amount: cost, // Value
                price: validPrice,
                date: Date(),
                fee: commission,
                currency: currency, // Explicit Currency
                pnl: nil,
                pnlPercent: nil,
                decisionTrace: decisionTrace,
                marketSnapshot: marketSnapshot,
                positionSnapshot: posSnapshot,
                execution: execution,
                outcome: nil,
                
                // Schema V2
                schemaVersion: 2,
                source: source == .autoPilot ? "AUTOPILOT" : "MANUAL",
                strategy: source == .autoPilot ? "CORSE" : "UNKNOWN",
                reasonCode: source == .autoPilot ? (rationale ?? "BUY_SIGNAL") : "MANUAL_TRADE",
                decisionContext: decisionTrace != nil ? makeDecisionContext(fromTrace: decisionTrace!) : (decisionTrace != nil && !self.agoraSnapshots.isEmpty ? makeDecisionContext(from: self.agoraSnapshots.last!) : nil),
                
                // Idempotency (ID V2)
                decisionId: !self.agoraSnapshots.isEmpty ? self.agoraSnapshots.last!.id.uuidString : nil,
                intentId: UUID().uuidString
            ))
            saveTransactions() // Persist immediately
            
            // Log Message (Currency aware)
            let currencySymbol = currency.symbol
            self.lastAction = "Alındı: \(String(format: "%.2f", quantity))x \(symbol) @ \(currencySymbol)\(String(format: "%.2f", validPrice))"

            
            // ARGUS VOICE (Phase 3)
            // Fire-and-forget generation
            if !self.agoraSnapshots.isEmpty, let snapshot = self.agoraSnapshots.last {
                Task {
                    let report = await ArgusVoiceService.shared.generateReport(from: snapshot)
                    await MainActor.run {
                        if let index = self.portfolio.firstIndex(where: { $0.id == newTrade.id }) {
                            self.portfolio[index].voiceReport = report
                        }
                    }
                }
            }
            
            // TRADE BRAIN: Pozisyon Planı Oluştur
            if let grandDecision = self.grandDecisions[symbol] {
                // Entry Snapshot kaydet
                let orionScore = self.orionScores[symbol]?.score ?? 50.0
                
                // Teknik veriler
                let candles = self.candles[symbol] ?? []
                var technicalData: TechnicalSnapshotData? = nil
                if candles.count >= 20 {
                    let closes = candles.map { $0.close }
                    let highs = candles.map { $0.high }
                    let lows = candles.map { $0.low }
                    
                    // Basit RSI hesaplama (son 14 gün)
                    var rsi: Double? = nil
                    if closes.count >= 15 {
                        var gains: Double = 0
                        var losses: Double = 0
                        let period = 14
                        let startIdx = closes.count - period - 1
                        for i in startIdx..<(closes.count - 1) {
                            let change = closes[i + 1] - closes[i]
                            if change > 0 { gains += change }
                            else { losses += abs(change) }
                        }
                        let avgGain = gains / Double(period)
                        let avgLoss = losses / Double(period)
                        if avgLoss > 0 {
                            let rs = avgGain / avgLoss
                            rsi = 100.0 - (100.0 / (1.0 + rs))
                        }
                    }
                    
                    // Basit ATR hesaplama
                    var atr: Double? = nil
                    if candles.count >= 15 {
                        var trSum: Double = 0
                        let period = 14
                        let startIdx = candles.count - period
                        for i in startIdx..<candles.count {
                            let high = highs[i]
                            let low = lows[i]
                            let prevClose = i > 0 ? closes[i - 1] : closes[i]
                            let tr = max(high - low, max(abs(high - prevClose), abs(low - prevClose)))
                            trSum += tr
                        }
                        atr = trSum / Double(period)
                    }
                    
                    // SMA'lar
                    let sma20: Double? = closes.count >= 20 ? closes.suffix(20).reduce(0, +) / 20.0 : nil
                    let sma50: Double? = closes.count >= 50 ? closes.suffix(50).reduce(0, +) / 50.0 : nil
                    let sma200: Double? = closes.count >= 200 ? closes.suffix(200).reduce(0, +) / 200.0 : nil
                    
                    // ATH uzaklığı
                    let ath = closes.max() ?? validPrice
                    let distanceFromATH = ((ath - validPrice) / ath) * 100
                    
                    technicalData = TechnicalSnapshotData(
                        rsi: rsi,
                        atr: atr,
                        sma20: sma20,
                        sma50: sma50,
                        sma200: sma200,
                        distanceFromATH: distanceFromATH,
                        distanceFrom52WeekLow: nil,
                        nearestSupport: nil,
                        nearestResistance: nil,
                        trend: nil
                    )
                }
                
                // Makro veriler
                let macroData = MacroSnapshotData(
                    vix: self.quotes["^VIX"]?.currentPrice,
                    spyPrice: self.quotes["SPY"]?.currentPrice,
                    marketMode: grandDecision.aetherDecision.marketMode
                )
                
                // Snapshot kaydet
                EntrySnapshotStore.shared.captureSnapshot(
                    for: newTrade,
                    grandDecision: grandDecision,
                    orionScore: orionScore,
                    atlasScore: nil,
                    technicalData: technicalData,
                    macroData: macroData,
                    fundamentalData: nil
                )
                
                // Plan oluştur
                PositionPlanStore.shared.createPlan(for: newTrade, decision: grandDecision)
            } else {
                // Grand Council kararı yoksa varsayılan neutral plan
                let defaultOrionDecision = CouncilDecision(
                    symbol: symbol,
                    action: .hold,
                    netSupport: 0.5,
                    approveWeight: 0,
                    vetoWeight: 0,
                    isStrongSignal: false,
                    isWeakSignal: false,
                    winningProposal: nil,
                    allProposals: [],
                    votes: [],
                    vetoReasons: [],
                    timestamp: Date()
                )
                
                let defaultAetherDecision = AetherDecision(
                    stance: .cautious,
                    marketMode: .neutral,
                    netSupport: 0.5,
                    isStrongSignal: false,
                    winningProposal: nil,
                    votes: [],
                    warnings: [],
                    timestamp: Date()
                )
                
                let defaultDecision = ArgusGrandDecision(
                    id: UUID(),
                    symbol: symbol,
                    action: source == .autoPilot ? .accumulate : .neutral,
                    strength: .normal,
                    confidence: 0.5,
                    reasoning: source == .autoPilot ? "AutoPilot Giriş" : "Manuel Giriş",
                    contributors: [],
                    vetoes: [],
                    orionDecision: defaultOrionDecision,
                    atlasDecision: nil,
                    aetherDecision: defaultAetherDecision,
                    hermesDecision: nil,
                    orionDetails: nil,
                    financialDetails: nil,
                    bistDetails: nil,
                    patterns: nil,
                    timestamp: Date()
                )
                PositionPlanStore.shared.createPlan(for: newTrade, decision: defaultDecision)
            }
        } else {
             self.lastAction = "Bakiye Yetersiz! (Gereken: $\(Int(totalCost)), Mevcut: $\(Int(balance)))"
        }
    }
    
    @MainActor
    func sell(symbol: String, quantity: Double, source: TradeSource = .user, engine: AutoPilotEngine? = nil, decisionTrace: DecisionTraceSnapshot? = nil, marketSnapshot: MarketSnapshot? = nil, reason: String? = nil) {
        
        // UNIFIED INPUT VALIDATION (Phase 1 Fix)
        let openTrades = portfolio.filter { $0.symbol == symbol && $0.isOpen }
        let totalOwned = openTrades.reduce(0.0) { $0 + $1.quantity }
        
        let validation = TradeValidator.validateSell(
            symbol: symbol,
            quantity: quantity,
            ownedQuantity: totalOwned,
            isBistMarketOpen: isBistMarketOpen(),
            isGlobalMarketOpen: MarketStatusService.shared.canTrade()
        )
        
        guard validation.isValid else {
            let errorMessage = validation.error?.localizedDescription ?? "Bilinmeyen hata"
            print("🛑 SATIŞ REDDEDİLDİ: \(errorMessage)")
            self.lastAction = "🛑 \(errorMessage)"
            return
        }
        
        // AGORA GUARDRAIL (Decision V2)
        // ----------------------------------------------------------------
        if let decision = argusDecisions[symbol] {
             let snapshot = AgoraExecutionGovernor.shared.audit(
                decision: decision,
                currentPrice: quotes[symbol]?.currentPrice ?? 0.0,
                portfolio: portfolio,
                lastTradeTime: lastTradeTimes[symbol],
                lastActionPrice: nil
            )
            
            if snapshot.locks.isLocked {
                 print("🛑 AGORA BLOCKED SELL: \(snapshot.reasonOneLiner)")
                 self.lastAction = "⚠️ İşlem Engellendi: \(snapshot.reasonOneLiner)"
                 self.agoraSnapshots.append(snapshot)
                 return
            }
        }
        // ----------------------------------------------------------------
        
        // Execution
        let price = quotes[symbol]?.currentPrice ?? 0.0
        let revenue = quantity * price
        let commission = FeeModel.shared.calculate(amount: revenue)
        let netRevenue = revenue - commission
        
        // BIST için TL bakiyesi, diğerleri için USD
        let isBist = symbol.uppercased().hasSuffix(".IS")
        if isBist {
            bistBalance += netRevenue
        } else {
            balance += netRevenue
        }
        
        // GHOST BUSTER: Explicit Log
        print("👻 GHOST BUSTER: Selling \(symbol). Reason: \(reason ?? "Unknown"). Price: \(price). Source: \(source).")
        
        let currencySymbol = isBist ? "₺" : "$"
        self.lastAction = "Satıldı: \(String(format: "%.2f", quantity))x \(symbol) (Net: \(currencySymbol)\(String(format: "%.2f", netRevenue)))"
        
        // Update Portfolio (FIFO Logic - First In First Out)
        var remainingToSell = quantity
        var totalRealizedPnL: Double = 0.0
        
        // We need to iterate by index to modify struct in array
        for i in 0..<portfolio.count {
            if portfolio[i].symbol == symbol && portfolio[i].isOpen {
                if remainingToSell <= 0 { break }
                
                let tradeQty = portfolio[i].quantity
                let tradeEntryPrice = portfolio[i].entryPrice
                
                if tradeQty <= remainingToSell {
                    // Fully Close this trade
                    let pnl = (price - tradeEntryPrice) * tradeQty
                    totalRealizedPnL += pnl
                    
                    portfolio[i].isOpen = false
                    portfolio[i].exitPrice = price
                    portfolio[i].exitDate = Date()
                    remainingToSell -= tradeQty
                    
                    // CHIRON LEARNING HOOK: Log trade outcome for learning
                    let closedTrade = portfolio[i]
                    Task {
                        let pnlPercent = ((price - tradeEntryPrice) / tradeEntryPrice) * 100
                        let record = TradeOutcomeRecord(
                            id: closedTrade.id,
                            symbol: symbol,
                            engine: closedTrade.engine ?? .pulse,
                            entryDate: closedTrade.entryDate,
                            exitDate: Date(),
                            entryPrice: tradeEntryPrice,
                            exitPrice: price,
                            pnlPercent: pnlPercent,
                            exitReason: reason ?? "MANUAL",
                            orionScoreAtEntry: self.orionScores[symbol]?.score,
                            atlasScoreAtEntry: FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore,
                            aetherScoreAtEntry: self.macroRating?.numericScore,
                            phoenixScoreAtEntry: nil,
                            allModuleScores: nil,
                            systemDecision: nil,
                            ignoredWarnings: nil,
                            regime: nil
                        )
                        await ChironDataLakeService.shared.logTrade(record)
                        print("🧠 Chiron: Trade logged for learning - \(symbol) \(pnlPercent > 0 ? "WIN" : "LOSS")")
                        
                        // 🆕 OTOMATİK ÖĞRENME TETİKLE - Her 3 trade'de 1 analiz
                        Task {
                            await ChironLearningJob.shared.analyzeSymbol(symbol)
                        }
                    }
                } else {
                    // Partial Close: Split trade
                    let soldPart = remainingToSell
                    // let remainingPart = tradeQty - soldPart // Unused for calc, used below
                    
                    let pnl = (price - tradeEntryPrice) * soldPart
                    totalRealizedPnL += pnl
                    
                    // 🆕 PARTIAL CLOSE'U DA LOGLA
                    let pnlPercent = ((price - tradeEntryPrice) / tradeEntryPrice) * 100
                    let record = TradeOutcomeRecord(
                        id: UUID(),
                        symbol: symbol,
                        engine: portfolio[i].engine ?? .pulse,
                        entryDate: portfolio[i].entryDate,
                        exitDate: Date(),
                        entryPrice: tradeEntryPrice,
                        exitPrice: price,
                        pnlPercent: pnlPercent,
                        exitReason: "PARTIAL_CLOSE",
                        orionScoreAtEntry: self.orionScores[symbol]?.score,
                        atlasScoreAtEntry: FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore,
                        aetherScoreAtEntry: self.macroRating?.numericScore,
                        phoenixScoreAtEntry: nil,
                        allModuleScores: nil,
                        systemDecision: nil,
                        ignoredWarnings: nil,
                        regime: nil
                    )
                    Task {
                        await ChironDataLakeService.shared.logTrade(record)
                        print("🧠 Chiron: Partial trade logged - \(symbol) \(pnlPercent > 0 ? "WIN" : "LOSS")")
                    }
                    
                    // Modify current to be "Sold"
                    portfolio[i].quantity = soldPart
                    portfolio[i].isOpen = false
                    portfolio[i].exitPrice = price
                    portfolio[i].exitDate = Date()
                    
                    // Create remainder
                    let remainderTrade = Trade(
                        id: UUID(),
                        symbol: symbol,
                        entryPrice: portfolio[i].entryPrice,
                        quantity: tradeQty - soldPart,
                        entryDate: portfolio[i].entryDate,
                        isOpen: true,
                        source: portfolio[i].source,
                        engine: portfolio[i].engine
                    )
                    portfolio.append(remainderTrade)
                    
                    remainingToSell = 0
                }
            }
        }
        
        // Calculate PnL Percent (Average)
    let totalCost = revenue - totalRealizedPnL // Revenue = Cost + Profit -> Cost = Revenue - Profit
    let pnlPercent = totalCost > 0 ? (totalRealizedPnL / totalCost) * 100 : 0.0
    
    // Build Execution Snapshot
    let execution = ExecutionSnapshot(
        orderType: "MARKET",
        requestedPrice: price,
        filledPrice: price,
        slippagePct: 0.0,
        latencyMs: 15.0,
        partialFill: false,
        requestedQty: quantity,
        filledQty: quantity,
        venue: "SIMULATION"
    )
    
    // Build Position Snapshot
    let posSnapshot = PositionSnapshot(
        positionQtyBefore: totalOwned,
        positionQtyAfter: totalOwned - quantity,
        avgCostBefore: 0, // Complex to calc avg cost here without loop
        avgCostAfter: 0,
        holdingSeconds: 0, // Need entry date delta
        unrealizedPnlBefore: 0,
        realizedPnlThisTrade: totalRealizedPnL,
        portfolioSnapshot: PositionSnapshot.PortfolioSnapshot(
            cashBefore: balance - netRevenue,
            cashAfter: balance,
            grossExposure: portfolio.filter { $0.isOpen }.reduce(0) { $0 + ($1.quantity * (quotes[$1.symbol]?.currentPrice ?? $1.entryPrice)) },
            netExposure: portfolio.filter { $0.isOpen }.reduce(0) { $0 + ($1.quantity * (quotes[$1.symbol]?.currentPrice ?? $1.entryPrice)) },
            positionsCount: portfolio.filter { $0.isOpen }.count
        )
    )
    
    // Log Transaction
    transactionHistory.append(Transaction(
        id: UUID(),
        type: .sell,
        symbol: symbol,
        amount: netRevenue,
        price: price,
        date: Date(),
        fee: commission,
        pnl: totalRealizedPnL,
        pnlPercent: pnlPercent,
        decisionTrace: decisionTrace,
        marketSnapshot: marketSnapshot,
        positionSnapshot: posSnapshot,
        execution: execution,
        outcome: nil,
        
        // Schema V2
        schemaVersion: 2,
        source: source == .autoPilot ? "AUTOPILOT" : "MANUAL",
        strategy: source == .autoPilot ? "CORSE" : "UNKNOWN",
        reasonCode: reason ?? (source == .autoPilot ? "SELL_SIGNAL" : "MANUAL_TRADE"),
        decisionContext: decisionTrace != nil && !self.agoraSnapshots.isEmpty ? makeDecisionContext(from: self.agoraSnapshots.last!) : nil,
        
        // Idempotency (ID V2)
        decisionId: !self.agoraSnapshots.isEmpty ? self.agoraSnapshots.last!.id.uuidString : nil,
        intentId: UUID().uuidString
    ))
    saveTransactions() // Persist immediately
    
    // CHIRON LEARNING HOOK: Trade kapandığında konsey ağırlıklarını güncelle
    if source == .autoPilot && abs(totalRealizedPnL) > 0.01 {
        let outcome: ChironTradeOutcome = totalRealizedPnL > 0 ? .win : .loss
        Task {
            await ChironCouncilLearningService.shared.updateOutcome(
                symbol: symbol,
                outcome: outcome,
                pnlPercent: pnlPercent
            )
            print("📚 Chiron Öğrenme: \(symbol) \(outcome.rawValue) (\(String(format: "%.2f", pnlPercent))%)")
        }
    }
    }
    
    func closeAllPositions(for symbol: String) {
        let openTrades = portfolio.filter { $0.symbol == symbol && $0.isOpen }
        let totalQty = openTrades.reduce(0.0) { $0 + $1.quantity }
        
        if totalQty > 0 {
            sell(symbol: symbol, quantity: totalQty, source: .user)
        }
    }
    

    
    // MARK: - Portfolio Calculations
    
    /// Global (USD) portfolio değerini hesaplar - BIST hisseleri hariç
    func getTotalPortfolioValue() -> Double {
        var total: Double = 0.0
        for trade in portfolio where trade.isOpen {
            // New Currency Check
            if trade.currency == .USD {
                if let quote = quotes[trade.symbol] {
                    total += quote.currentPrice * trade.quantity
                }
            }
        }
        return total
    }
    
    /// BIST (TL) portfolio değerini hesaplar
    func getBistPortfolioValue() -> Double {
        var total: Double = 0.0
        for trade in portfolio where trade.isOpen {
            // New Currency Check
            if trade.currency == .TRY {
                if let quote = quotes[trade.symbol] {
                    total += quote.currentPrice * trade.quantity
                }
            }
        }
        return total
    }
    
    /// Global (USD) henüz gerçekleşmemiş kar/zarar
    func getUnrealizedPnL() -> Double {
        var totalPnL = 0.0
        for trade in portfolio where trade.isOpen {
            if trade.currency == .USD {
                if let currentPrice = quotes[trade.symbol]?.currentPrice {
                    let diff = currentPrice - trade.entryPrice
                    totalPnL += diff * trade.quantity
                }
            }
        }
        return totalPnL
    }
    
    /// BIST (TL) henüz gerçekleşmemiş kar/zarar
    func getBistUnrealizedPnL() -> Double {
        var totalPnL = 0.0
        for trade in portfolio where trade.isOpen {
            if trade.currency == .TRY {
                if let currentPrice = quotes[trade.symbol]?.currentPrice {
                    let diff = currentPrice - trade.entryPrice
                    totalPnL += diff * trade.quantity
                }
            }
        }
        return totalPnL
    }
    
    func getRealizedPnL() -> Double {
        var totalPnL: Double = 0.0
        for trade in portfolio where !trade.isOpen {
             // Use the trade's computed profit property
             totalPnL += trade.profit
        }
        return totalPnL
    }
    
    func getWinRate() -> Double {
        let closedTrades = portfolio.filter { !$0.isOpen }
        guard !closedTrades.isEmpty else { return 0.0 }
        
        // Use profit > 0
        let winningTrades = closedTrades.filter { $0.profit > 0 }
        
        return (Double(winningTrades.count) / Double(closedTrades.count)) * 100.0
    }
    
    // MARK: - Advanced Portfolio Metrics
    
    /// Global (USD) toplam varlık = USD bakiye + USD portfolio değeri
    func getEquity() -> Double {
        return balance + getTotalPortfolioValue()
    }
    
    /// BIST (TL) toplam varlık = TL bakiye + TL portfolio değeri
    func getBistEquity() -> Double {
        return bistBalance + getBistPortfolioValue()
    }
    
    // Margin helpers removed as per user request for "Spot Trading" only.
    
    // MARK: - Discover & Helpers
    
    struct DiscoverCategory: Identifiable {
        let id = UUID()
        let title: String
        let symbols: [String]
    }
    
    var discoverCategories: [DiscoverCategory] {
        var categories = [
            DiscoverCategory(title: "Popüler Teknoloji", symbols: ["AAPL", "MSFT", "NVDA", "GOOGL", "META"]),
            DiscoverCategory(title: "Elektrikli Araçlar", symbols: ["TSLA", "RIVN", "LCID", "NIO"]),
            DiscoverCategory(title: "Finans", symbols: ["JPM", "BAC", "V", "MA"]),
            DiscoverCategory(title: "Yarı İletkenler", symbols: ["AMD", "INTC", "TSM", "QCOM"])
        ]
        
        // Tüm discover sembollerini topla
        // let allSymbols = categories.flatMap { $0.symbols }
        
        // --- SAFE UNIVERSE LOADING ---
        // Ensure we handle Safe Assets too (DXY, Gold, etc.)
        Task {
            let safeAssets = SafeUniverseService.shared.universe.map { $0.symbol }
            for symbol in safeAssets {
                 // Prioritize Yahoo routing (implicit in MarketDataProvider)
                 if quotes[symbol] == nil {
                     let val = await MarketDataStore.shared.ensureQuote(symbol: symbol)
                     if let quote = val.value {
                         await MainActor.run { self.quotes[symbol] = quote }
                     }
                 }
                 // Trigger Argus analysis for these too (lightweight)
                 if argusDecisions[symbol] == nil {
                     await loadArgusData(for: symbol)
                 }
            }
        }
        // -----------------------------
        
        // Quotes varsa Gainers/Losers hesapla
        if !quotes.isEmpty {
            // let sortedQuotes = quotes.values.sorted { $0.percentChange > $1.percentChange }
            
            // MarketDataProvider'daki Quote struct'ında symbol yok. Dictionary key'den buluyoruz.
            // Bu yüzden quotes dictionary'sini (key, value) olarak sort etmeliyiz.
            
            let sortedSymbols = quotes.sorted { $0.value.percentChange > $1.value.percentChange }
            
            let topGainers = sortedSymbols.prefix(5).map { $0.key }
            let topLosers = sortedSymbols.suffix(5).reversed().map { $0.key }
            
            if !topGainers.isEmpty {
                categories.insert(DiscoverCategory(title: "En Çok Yükselenler 🚀", symbols: topGainers), at: 0)
            }
            
            if !topLosers.isEmpty {
                categories.append(DiscoverCategory(title: "En Çok Düşenler 🔻", symbols: topLosers))
            }
        }
        
        return categories
    }
    
    // Discover sembollerini de yüklemek için yardımcı fonksiyon
    // Discover sembollerini de yüklemek için yardımcı fonksiyon (DEPRECATED - Moved to new implementation below)
    // Removed old loadDiscoverData to avoid redeclaration error.
    

    
    // Eski Composite Score desteği (DiscoverView için mock veya boş)
    // DiscoverView'da 'compositeScores' kullanılıyor.
    // Yeni sistemde 'FundamentalScoreResult' var.
    // DiscoverView'ı kırmamak için boş bir dictionary veya uyumlu bir yapı dönelim.
    // Ancak DiscoverView eski 'CompositeScore' tipini bekliyor olabilir.
    // En iyisi DiscoverView'ı güncellemek ama şimdilik ViewModel'i onaralım.
    // DiscoverView satır 48: if let score = viewModel.compositeScores[symbol]
    // Bu 'score' objesinin 'totalScore' özelliği var.
    // Bizim FundamentalScoreResult da 'totalScore'a sahip.
    // O yüzden tip uyuşmazlığı olabilir ama isim benzerliği kurtarabilir.
    // Swift type-safe olduğu için DiscoverView'ın beklediği tipi bilmem lazım.
    // Muhtemelen eski bir struct vardı.
    // Şimdilik DiscoverView'daki hatayı çözmek için:
    // compositeScores'u FundamentalScoreResult olarak tanımlayalım (Store'dan çekip).
    
    var compositeScores: [String: FundamentalScoreResult] {
        var scores: [String: FundamentalScoreResult] = [:]
        for symbol in watchlist {
            if let score = fundamentalScoreStore.getScore(for: symbol) {
                scores[symbol] = score
            }
        }
        // Discover'daki semboller watchlist'te olmayabilir, onlar için de store'a bakmak lazım ama
        // store sadece hesaplananları tutuyor.
        return scores
    }
    
    func refreshSymbol(_ symbol: String) {
        Task {
            // SSoT Fetch
            await MarketDataStore.shared.ensureQuote(symbol: symbol)
        }
    }
    
    // PortfolioView için overload
    // PortfolioView için overload
    func sell(tradeId: UUID, currentPrice: Double, quantity: Double? = nil, reason: String? = nil, source: TradeSource = .user) {
        if let index = portfolio.firstIndex(where: { $0.id == tradeId }) {
            let trade = portfolio[index]
            let qtyToSell = quantity ?? trade.quantity // Default to full
            sell(symbol: trade.symbol, quantity: qtyToSell, source: source, reason: reason)
        }
    }
    
    func updateTradeHighWaterMark(symbol: String, price: Double) {
        if let index = portfolio.firstIndex(where: { $0.symbol == symbol && $0.isOpen }) {
            var trade = portfolio[index]
            let oldMark = trade.highWaterMark ?? trade.entryPrice
            if price > oldMark {
                trade.highWaterMark = price
                portfolio[index] = trade
                savePortfolio()
                // print("🌊 High Water Mark Updated: \(symbol) -> \(price)")
            }
        }
    }

    // MARK: - Discovery Data Fetching
    
    // MARK: - Market Pulse (Discover)
    
    // refreshMarketPulse moved to TradingViewModel+MarketData.swift
    
    // MARK: - SSoT Binding
    func setupStoreBindings() {
        // Sync Quotes from Store to ViewModel to support legacy Views
        MarketDataStore.shared.$quotes
            .throttle(for: .seconds(0.5), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] storeQuotes in
                // Efficiently update local cache. 
                // In a pure SSoT app, views would read Store directly.
                // Here we bridge for compatibility.
                // We only copy VALUES to keep struct simple for UI.
                var cleanQuotes: [String: Quote] = [:]
                for (sym, dv) in storeQuotes {
                    if let val = dv.value {
                        cleanQuotes[sym] = val
                    }
                }
                self?.quotes = cleanQuotes
            }
            .store(in: &cancellables)
            
        // Sync Candles similarly if needed, or rely on ensureCandles return
    }

    
    // RadarStrategy and getRadarPicks moved to TradingViewModel+MarketData.swift
    
    // getHermesHighlights moved to TradingViewModel+Hermes.swift
    
    // MARK: - Discovery Data Loading
    
    // Discovery methods moved to TradingViewModel+MarketData.swift

    // MARK: - News & Insights (Gemini)
    
    @Published var newsBySymbol: [String: [NewsArticle]] = [:]
    @Published var newsInsightsBySymbol: [String: [NewsInsight]] = [:]
    
    // Hermes Feeds
    @Published var watchlistNewsInsights: [NewsInsight] = [] // Tab 1: "Takip Listem"
    @Published var generalNewsInsights: [NewsInsight] = []   // Tab 2: "Genel Piyasa"
    
    @Published var isLoadingNews: Bool = false
    @Published var newsErrorMessage: String? = nil
    
    @MainActor
    // Hermes methods moved to TradingViewModel+Hermes.swift
    
    // MARK: - Passive AutoPilot Scanner (NVDA Fix)
    // Scan high-scoring assets in Watchlist/Portfolio that might NOT have news but are Technical/Fundamental screaming buys.
    
    // AutoPilot methods moved to TradingViewModel+AutoPilot.swift
    

    // MARK: - Simulation / Debug

    func simulateOverreactionTest(symbol: String) async {
        self.isLoadingArgus = true
        
        // 1. Generate Synthetic "Crash" Candles
        var candles: [Candle] = []
        let end = Date()
        var price = 150.0
        
        // 60 days of history
        for i in 0..<60 {
            let date = Calendar.current.date(byAdding: .day, value: -60 + i, to: end)!
            
            // Normal volatility
            let change = Double.random(in: -0.01...0.01)
            let open = price
            let close = price * (1 + change)
            let high = max(open, close) * 1.005
            let low = min(open, close) * 0.995
            let vol = 10_000_000.0 // 10M Avg
            
            candles.append(Candle(date: date, open: open, high: high, low: low, close: close, volume: vol))
            price = close
        }
        
        // THE CRASH DAY (Last Candle)
        // Gap down 3%, drop another 3% intraday => -6% total
        // Vol Spike 3x
        let crashDate = Date()
        let prevClose = candles.last!.close
        let crashOpen = prevClose * 0.97 // Gap Down
        let crashClose = crashOpen * 0.97 // Intraday Flush
        let crashHigh = crashOpen
        let crashLow = crashClose * 0.99
        let crashVol = 35_000_000.0 // 3.5x Spike
        
        candles.append(Candle(date: crashDate, open: crashOpen, high: crashHigh, low: crashLow, close: crashClose, volume: crashVol))
        
        // 2. Mock Scores
        let mockAtlas = 75.0 // High Quality
        let mockAether = 45.0 // Fearful Market
        
        // 3. Analyze
        self.analyzeOverreaction(symbol: symbol, candles: candles, atlas: mockAtlas, aether: mockAether)
        
        // Artificial delay for effect
        try? await Task.sleep(nanoseconds: 500_000_000)
        self.isLoadingArgus = false
    }
    
    // MARK: - Live Mode (TradingView Bridge) (Experimental)
    
    // MARK: - Live Mode Logic
    
    private func startLiveSession() {
        print("🚀 Argus: Live Session Logic Activated")
        // In a real implementation, this might connect a socket or increase poll rate.
        // Currently, MarketDataStore handles the stream centrally.
    }

    private func stopLiveSession() {
        print("🛑 Argus: Live Session Logic Deactivated")
    }

    
    // Stub for safety if missing in this file (usually exists in AutoPilot section)
    // checkAutoPilotTriggers moved to TradingViewModel+AutoPilot.swift
}

// MARK: - Export Helpers (Argus Enriched)
extension TradingViewModel {
    
    
    func makeDecisionTraceSnapshot(from snapshot: DecisionSnapshot, mode: String) -> DecisionTraceSnapshot {
        return DecisionTraceSnapshot(
            mode: mode,
            overallScore: 50.0, // Simplified mapping
            scores: DecisionTraceSnapshot.ScoresSnapshot(
                atlas: (snapshot.evidence.first(where: { $0.module == "Atlas" })?.confidence ?? 0.0) * 100,
                orion: (snapshot.evidence.first(where: { $0.module == "Orion" })?.confidence ?? 0.0) * 100,
                aether: snapshot.riskContext?.aetherScore ?? 50.0,
                hermes: 50.0,
                demeter: 50.0
            ),
            thresholds: DecisionTraceSnapshot.ThresholdsSnapshot(
                buyOverallMin: 0, sellOverallMin: 0, orionMin: 0, atlasMin: 0, aetherMin: 0, hermesMin: 0
            ),
            reasonsTop3: snapshot.dominantSignals.map {
                DecisionTraceSnapshot.ReasonSnapshot(key: "Signal", value: nil, note: $0)
            },
            guards: DecisionTraceSnapshot.GuardsSnapshot(
                cooldownActive: snapshot.locks.cooldownUntil != nil,
                minHoldBlocked: snapshot.locks.minHoldUntil != nil,
                minMoveBlocked: false,
                costGateBlocked: false,
                rebalanceBandBlocked: false,
                rateLimitBlocked: snapshot.locks.isLocked,
                otherBlocked: snapshot.locks.isLocked
            ),
            blockReason: snapshot.locks.isLocked ? snapshot.reasonOneLiner : nil,
            phoenix: snapshot.phoenix,
            standardizedOutputs: snapshot.standardizedOutputs
        )
    }
    

    
    func makeMarketSnapshot(for symbol: String, currentPrice: Double) -> MarketSnapshot {
        // Simplified Snapshot
        return MarketSnapshot(
            bid: currentPrice, ask: currentPrice, spreadPct: 0.0, atr: nil,
            returns: MarketSnapshot.ReturnsSnapshot(r1m: nil, r5m: nil, r1h: nil, r1d: nil, rangePct: nil, gapPct: nil),
            barsSummary: MarketSnapshot.BarsSummarySnapshot(lookback: 20, high: nil, low: nil, close: currentPrice),
            barTimestamp: Date(), // Current Bar Time
            signalPrice: currentPrice,
            volatilityHint: nil // Can plug in ATR or VIX later
        )
    }
    
    func makeDecisionContext(fromTrace trace: DecisionTraceSnapshot) -> DecisionContext {
        // Map Scores to Votes ( Simplified )
        return DecisionContext(
            decisionId: UUID().uuidString, // Trace doesn't always have ID, gen new
            overallAction: "BUY", // Assumed from context
            dominantSignals: trace.reasonsTop3.compactMap { $0.note },
            conflicts: [],
            moduleVotes: ModuleVotes(
                atlas: ModuleVote(score: trace.scores.atlas ?? 0.0, direction: "BUY", confidence: (trace.scores.atlas ?? 0.0) / 100.0),
                orion: ModuleVote(score: trace.scores.orion ?? 0.0, direction: "BUY", confidence: (trace.scores.orion ?? 0.0) / 100.0),
                aether: ModuleVote(score: trace.scores.aether ?? 50.0, direction: "NEUTRAL", confidence: 0.5),
                hermes: ModuleVote(score: trace.scores.hermes ?? 50.0, direction: "NEUTRAL", confidence: 0.5),
                chiron: nil
            )
        )
    }

    func makeDecisionContext(from snapshot: DecisionSnapshot) -> DecisionContext {
        // Map Evidence to Votes
        // We iterate evidence and pick matching modules
        let findVote = { (module: String) -> ModuleVote? in
            guard let ev = snapshot.evidence.first(where: { $0.module == module }) else { return nil }
            return ModuleVote(score: ev.confidence, direction: ev.direction, confidence: ev.confidence) // FIXED: direction
        }
        
        let votes = ModuleVotes(
            atlas: findVote("Atlas"),
            orion: findVote("Orion"),
            aether: findVote("Aether"),
            hermes: findVote("Hermes"),
            chiron: findVote("Chiron")
        )
        
        let conflicts = snapshot.conflicts.map { c in
            DecisionConflict(moduleA: c.moduleA, moduleB: c.moduleB, topic: c.topic, severity: 0.5) // FIXED: topic
        }
        
        return DecisionContext(
            decisionId: snapshot.id.uuidString,
            overallAction: snapshot.action.rawValue,
            dominantSignals: snapshot.dominantSignals,
            conflicts: conflicts,
            moduleVotes: votes
        )
    }
    
    func recordAttempt(symbol: String, action: TradeAction, price: Double, decisionTrace: DecisionTraceSnapshot, marketSnapshot: MarketSnapshot, blockReason: String, decisionSnapshot: DecisionSnapshot? = nil) {
        // Try to get DecisionContext if snapshot provided
        var dContext: DecisionContext? = nil
        if let ds = decisionSnapshot {
            dContext = makeDecisionContext(from: ds)
        }
    
        let attempt = Transaction(
            id: UUID(),
            type: .attempt,
            symbol: symbol,
            amount: 0,
            price: price,
            date: Date(),
            fee: 0,
            pnl: nil,
            pnlPercent: nil,
            decisionTrace: decisionTrace,
            marketSnapshot: marketSnapshot,
            positionSnapshot: nil,
            execution: nil,
            outcome: nil,
            schemaVersion: 2,
            source: "SYSTEM_GUARD",
            strategy: "UNKNOWN",
            reasonCode: blockReason,
            decisionContext: dContext,
            cooldownUntil: decisionSnapshot?.locks.cooldownUntil,
            minHoldUntil: decisionSnapshot?.locks.minHoldUntil,
            guardrailHit: true,
            guardrailReason: blockReason
        )
        transactionHistory.append(attempt)
        saveTransactions() // Persist immediately
    }    

    var bistPortfolio: [Trade] {
        portfolio.filter { $0.currency == .TRY }
    }

    var globalPortfolio: [Trade] {
        portfolio.filter { $0.currency == .USD }
    }
    
    
    // Logları filtrele: Sadece Global semboller (BIST olmayanlar) - Loglarda currency alanı yoksa symbol kontrolüne devam etmek zorunda kalabiliriz ama trade üzerinden gidiyorsak currency kullanırız. ScoutLog içinde currency yok, o yüzden burada symbol check kalmalı ya da ScoutLog güncellenmeli. Ancak ScoutLog trade değil. Burada symbol check mecburen kalacak veya ScoutLog'a da eklemeliyiz. Şimdilik symbol check devam etsin ama SymbolResolver ile destekli.
    var globalScoutLogs: [ScoutLog] {
        scoutLogs.filter { !($0.symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol($0.symbol)) }
    }

    // MARK: - BIST Tam Reset Functions
    func resetBistPortfolio() {
        print("🚨 BIST PORTFÖYÜ SIFIRLANIYOR...")
        
        // 1. BIST Pozisyonlarını Sil
        portfolio.removeAll { trade in
            trade.currency == .TRY
        }
        savePortfolio()
        print("✅ BIST pozisyonları silindi.")
        
        // 2. BIST İşlem Geçmişini Sil - Transaction modelinde currency yoksa symbol check devam
        transactionHistory.removeAll { tx in
            tx.symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(tx.symbol)
        }
        saveTransactions()
        print("✅ BIST işlem geçmişi silindi.")
        
        // 3. Bakiyeyi Sıfırla (1M TL)
        bistBalance = 1_000_000.0
        saveBistBalance()
        print("✅ Bakiye 1.000.000 TL olarak ayarlandı.")
    }
    
    // MARK: - Smart Rebalancing (Portföy Dengesi Analizi - GLOBAL ONLY)
    
    /// Her pozisyonun portföy içindeki yüzde ağırlığı (Sadece Global/USD)
    /// NOT: BIST için ayrı bir allocation hesabı yapılmalı
    var portfolioAllocation: [String: PortfolioAllocationItem] {
        let totalEquity = getEquity() // Sadece Global Equity
        guard totalEquity > 0 else { return [:] }
        
        var allocation: [String: PortfolioAllocationItem] = [:]
        
        for trade in portfolio where trade.isOpen && trade.currency == .USD {
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let positionValue = currentPrice * trade.quantity
            let percentage = (positionValue / totalEquity) * 100
            
            allocation[trade.symbol] = PortfolioAllocationItem(
                symbol: trade.symbol,
                value: positionValue,
                percentage: percentage,
                quantity: trade.quantity
            )
        }
        
        return allocation
    }
    
    /// Konsantrasyon uyarıları (basit string formatında)
    var concentrationWarnings: [String] {
        var warnings: [String] = []
        
        for (symbol, item) in portfolioAllocation {
            // Tek pozisyon > %25 uyarısı
            if item.percentage > 25 {
                let emoji = item.percentage > 35 ? "🚨" : "⚠️"
                warnings.append("\(emoji) \(symbol) portföyün %\(Int(item.percentage))'ini oluşturuyor. Max önerilen: %25")
            }
        }
        
        return warnings.sorted()
    }
    
    /// En büyük pozisyonlar (Top N)
    func topPositions(count: Int = 5) -> [PortfolioAllocationItem] {
        return portfolioAllocation.values.sorted { $0.percentage > $1.percentage }.prefix(count).map { $0 }
    }

}

// MARK: - Portfolio Allocation Models

struct PortfolioAllocationItem: Identifiable {
    var id: String { symbol }
    let symbol: String
    let value: Double
    let percentage: Double
    let quantity: Double
}

