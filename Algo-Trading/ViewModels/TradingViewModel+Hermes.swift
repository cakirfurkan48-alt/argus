import Foundation
import SwiftUI
import Combine

// MARK: - Hermes News Integration
extension TradingViewModel {

    // MARK: - News & Insights (Gemini)
    // Note: Published properties must remain in the main class.
    
    @MainActor
    func loadNewsAndInsights(for symbol: String, isGeneral: Bool = false) {
        // Reset state only if specific symbol fetch failing affects UI state differently
        isLoadingNews = true
        newsErrorMessage = nil
        
        Task {
            do {
                // FORCE CLEANUP: If specific symbol, clear potentially bad cache (Temporary Fix for "fnda..." issue)
                // In production, we'd use versioning, but here let's just ignore cache for specific symbol fetch once.
                // Or better: The RSS/Finnhub provider handles caching. We can tell it to ignore cache?
                // For now, let's rely on the new strict filter. Even if cache returns junk, the filter will kill it.
                // BUT if filter kills it, we show 'No News'. That is better than 'Bad News'.
                
                // 1. Fetch News (Fetch MORE to filter bad apples)
                let articles = try await AggregatedNewsService.shared.fetchNews(symbol: symbol, limit: 20)
                
                if !isGeneral {
                    self.newsBySymbol[symbol] = articles
                }
                
                // 2. Analyze Top Articles
                // General: Analyze top 5
                // Watchlist/Detail: Fetch 5, Filter strict relevance, Analyze BEST 1-3.
                var candidates = articles
                
                if !isGeneral {
                    // STRICT FILTER ENHANCED: Ticker OR Company Name
                    // Users complain "AMZN" news exists in General but isn't found here because headline says "Amazon".
                    
                    let aliases: [String: [String]] = [
                        "AAPL": ["APPLE", "IPHONE", "IPAD", "MACBOOK"],
                        "AMZN": ["AMAZON", "AWS", "PRIME"],
                        "GOOGL": ["GOOGLE", "ALPHABET", "YOUTUBE", "GEMINI"],
                        "GOOG": ["GOOGLE", "ALPHABET", "YOUTUBE"],
                        "MSFT": ["MICROSOFT", "WINDOWS", "AZURE", "OPENAI"],
                        "TSLA": ["TESLA", "MUSK", "CYBERTRUCK"],
                        "NVDA": ["NVIDIA", "GPU", "AI CHIP"],
                        "META": ["META", "FACEBOOK", "INSTAGRAM", "WHATSAPP"],
                        "NFLX": ["NETFLIX"],
                        "AMD": ["AMD", "ADVANCED MICRO"],
                        "INTC": ["INTEL"],
                        "AVGO": ["BROADCOM"],
                        "ORCL": ["ORACLE"],
                        "CRM": ["SALESFORCE"],
                        "ADBE": ["ADOBE"],
                        "QCOM": ["QUALCOMM"],
                        "IBM": ["IBM"],
                        "CSCO": ["CISCO"],
                        "UBER": ["UBER"],
                        "ABNB": ["AIRBNB"],
                        "PLTR": ["PALANTIR"],
                        "COIN": ["COINBASE", "BITCOIN", "CRYPTO"], // Contextual
                        "HOOD": ["ROBINHOOD"],
                        "BABA": ["ALIBABA"],
                        "BIDU": ["BAIDU"],
                        "TCEHY": ["TENCENT"],
                        "TSM": ["TAIWAN SEMI", "TSMC"]
                    ]
                    
                    let symbolUpper = symbol.uppercased()
                    let symbolAliases = aliases[symbolUpper] ?? []
                    
                    candidates = articles.filter { article in
                        let headline = article.headline.uppercased()
                        // 1. Check Ticker
                        if headline.contains(symbolUpper) { return true }
                        // 2. Check Aliases
                        for alias in symbolAliases {
                            if headline.contains(alias) { return true }
                        }
                        return false
                    }
                    
                    // Fallback: If strict filter killed everything, check GENERAL FEED for matches!
                    // Maybe we already fetched it there?
                    if candidates.isEmpty { 
                        let generalMatches = self.generalNewsInsights.filter { insight in
                             // FIX: Use insight.symbol instead of headline text matching
                             // This prevents "Jack In The Box vs McDonald's" news from appearing on MCD
                             return insight.symbol.uppercased() == symbolUpper
                        }
                        
                        if !generalMatches.isEmpty {
                            print("Hermes: Found relevant news in General Feed for \(symbol). Using it.")
                            // Map Insight back to 'Article' context? 
                            // Actually, we can just append these insights to our list directly!
                            // But here we are building 'candidates' (Articles).
                            // We can use a trick: If we have insights, we skip the loop below and just assign them.
                             self.newsInsightsBySymbol[symbol] = generalMatches
                             self.isLoadingNews = false
                             await self.loadArgusData(for: symbol) // Don't forget to recalc!
                             return
                        }
                        
                        // Last Resort: If absolutely nothing, return nothing.
                        print("Hermes: No relevant news found for \(symbol) (Strict Filter + General Check). Skipping.")
                        self.isLoadingNews = false
                        return 
                    }
                }
                
                // Limit Logic
                let limit = isGeneral ? 5 : 2 // Analyze Top 2 for specific (to improve chances of hit)
                let topArticles = Array(candidates.prefix(limit))
                var insights: [NewsInsight] = []
                
                for article in topArticles {
                    // Check if we already analyzed this article in the relevant list
                    let targetList = isGeneral ? self.generalNewsInsights : self.watchlistNewsInsights
                    
                    if let existing = targetList.first(where: { $0.articleId == article.id }) {
                        insights.append(existing)
                        continue
                    }
                    
                    do {
                        // Dynamic Delay:
                        // General Pipeline can be faster (less calls). Watchlist needs spacing.
                        let sleepTime: UInt64 = isGeneral ? 500_000_000 : 1_500_000_000 // 0.5s vs 1.5s
                        try? await Task.sleep(nanoseconds: sleepTime)
                        
                        // For General news, we might want to pass "GENERAL" as symbol to prompt, or the actual symbol if available?
                        // Finnhub General News doesn't always have a ticker. Let's use "MARKET" if general.
                         let analysisSymbol = isGeneral ? "MARKET" : symbol
                        
                        let insight = try await GeminiNewsService.shared.analyzeNews(symbol: analysisSymbol, article: article)
                        insights.append(insight)
                        
                        // HERMES DISCOVERY: Check for new opportunities
                        if let tickers = insight.relatedTickers, !tickers.isEmpty {
                            Task { await self.analyzeDiscoveryCandidates(tickers, source: insight) }
                        }
                        
                        // Add to Relevant Feed immediately
                        if isGeneral {
                            if !self.generalNewsInsights.contains(where: { $0.articleId == article.id }) {
                                self.generalNewsInsights.append(insight)
                            }
                        } else {
                            if !self.watchlistNewsInsights.contains(where: { $0.articleId == article.id }) {
                                self.watchlistNewsInsights.append(insight)
                            }
                        }
                    } catch {
                        print("Gemini Analysis Failed for article: \(article.headline). Error: \(error)")
                        
                        // Fallback: Create Insight without AI Analysis
                        let errorMessage = error.localizedDescription
                        let impactMsg = "Hata: \(errorMessage)" // Full error
                        
                        let fallbackInsight = NewsInsight(
                            id: UUID(),
                            symbol: article.symbol,
                            articleId: article.id,
                            headline: article.headline,
                            summaryTRLong: article.summary ?? "Detay bulunamadı.",
                            impactSentenceTR: impactMsg,
                            sentiment: .neutral,
                            confidence: 0.0,
                            impactScore: 50.0, // Default neutral
                            relatedTickers: nil,
                            createdAt: article.publishedAt
                        )
                        insights.append(fallbackInsight)
                        
                        // Add to Relevant Feed immediately
                        if isGeneral {
                            // Fix potential issue where contains check might be comparing different ID types if logic differed,
                            // but here we check by articleId (String) which is safe.
                            if !self.generalNewsInsights.contains(where: { $0.articleId == article.id }) {
                                self.generalNewsInsights.append(fallbackInsight)
                            }
                        } else {
                            if !self.watchlistNewsInsights.contains(where: { $0.articleId == article.id }) {
                                self.watchlistNewsInsights.append(fallbackInsight)
                            }
                        }
                    }
                }
                
                if !isGeneral {
                    self.newsInsightsBySymbol[symbol] = insights
                }
                
                // Re-sort Feeds (Newest first)
                if isGeneral {
                    self.generalNewsInsights.sort { $0.createdAt > $1.createdAt }
                } else {
                    self.watchlistNewsInsights.sort { $0.createdAt > $1.createdAt }
                    
                    // CRITICAL FIX: Do NOT re-calculate Argus Score automatically here.
                    // This triggers a massive "Chain Reaction" (Candles + Financials + LLM) for every symbol in the watchlist.
                    // This caused the API Bans.
                    // Instead, Argus Score should be calculated Lazily when the user opens the Detail View.
                    // await self.loadArgusData(for: symbol) 
                }
                
                self.isLoadingNews = false
                
            } catch {
                self.isLoadingNews = false
                self.newsErrorMessage = "Haber akışı alınamadı: \(error.localizedDescription)"
                print("News fetch error: \(error)")
            }
        }
    }
    
    // Hermes: Load Watchlist Feed
    @MainActor
    func loadWatchlistFeed() {
        isLoadingNews = true
        
        // Define key symbols + Watchlist
        let keySymbols = ["SPY", "QQQ", "BTC-USD", "ETH-USD"]
        let allSymbols = Set(keySymbols + watchlist).prefix(8) // Increased to 8
        
        Task {
            for symbol in allSymbols {
                 loadNewsAndInsights(for: symbol, isGeneral: false)
                 // Increase delay between symbols to avoid hitting Rate Limit (429)
                 try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0s between symbols
            }
            
            // After News Scan, run Passive High Conviction Scan
            await scanHighConvictionCandidates()
        }
    }
    

    
    // Hermes: Load General Feed
    func loadGeneralFeed() {
        isLoadingNews = true
        loadNewsAndInsights(for: "GENERAL", isGeneral: true)
    }
    
    func getHermesHighlights() -> [NewsInsight] {
        var allInsights: [NewsInsight] = []
        for list in newsInsightsBySymbol.values {
            allInsights.append(contentsOf: list)
        }
        
        return allInsights
            .filter { $0.confidence > 0.6 }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - Manual Analysis (Sanctum Button)
    @MainActor
    func analyzeOnDemand(symbol: String) async {
        self.isLoadingNews = true
        
        // 1. Trigger Coordinator Analysis
        // This fetches fresh news if needed and runs LLM
        _ = await HermesCoordinator.shared.analyzeOnDemand(symbol: symbol)
        
        // 2. Refresh UI from Cache (SSoT)
        let summaries = HermesCacheStore.shared.getSummaries(for: symbol)
        self.hermesSummaries[symbol] = summaries
        
        // 3. Populate Insights for ArgusSanctumView
        // This ensures the view sees the data immediately without waiting for background refresh
        self.newsInsightsBySymbol[symbol] = summaries.map { summary in
             NewsInsight(
                id: UUID(), // Generate ephemeral ID for UI view
                symbol: symbol,
                articleId: summary.id,
                headline: summary.summaryTR,
                summaryTRLong: summary.impactCommentTR,
                impactSentenceTR: summary.impactCommentTR,
                sentiment: summary.impactScore > 60 ? .strongPositive : (summary.impactScore < 40 ? .strongNegative : .neutral),
                confidence: 0.85, // High confidence as it is human/AI verified
                impactScore: Double(summary.impactScore),
                relatedTickers: nil,
                createdAt: summary.createdAt
            )
        }
        
        self.hermesMode = HermesCoordinator.shared.getCurrentMode()
        self.isLoadingNews = false
        
        // 4. Trigger Argus Recalculation (to update Atlas/Etf scores affected by news)
        // Background task to keep UI responsive
        Task {
            await loadArgusData(for: symbol)
        }
    }
}
