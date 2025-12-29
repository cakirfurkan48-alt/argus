import Foundation

/// Main Coordinator for Hermes Integration.
/// Manages fetching news, checking cache, batching AI calls, and fallback to Lite mode.
final class HermesCoordinator: Sendable {
    static let shared = HermesCoordinator()
    
    private let cache = HermesCacheStore.shared
    private let llmService = HermesLLMService.shared
    
    // State
    private var isLiteMode = false
    
    private init() {}
    
    func getHermesSummaries(for symbol: String) async -> [HermesSummary] {
        return []
    }
    
    /// On-Demand Analysis (Triggered by UI)
    /// Fetches news and runs AI analysis, returning average score.
    func analyzeOnDemand(symbol: String) async -> Double? {
        // 1. Fetch News (Using Heimdall - FMP/Finnhub/Yahoo)
        do {
            let articles = try await HeimdallOrchestrator.shared.requestNews(symbol: symbol, context: .interactive)
            
            // 2. Process with AI (Grok) - Force AI Mode
            let summaries = await processNews(articles: articles, allowAI: true)
            
            if summaries.isEmpty { return nil }
            
            // 3. Calculate Average Score
            let total = summaries.map { Double($0.impactScore) }.reduce(0.0, +)
            let avg = total / Double(summaries.count)
            return avg
        } catch {
            print("❌ Hermes On-Demand Error: \(error)")
            return nil
        }
    }
    
    /// Main Entry Point
    func processNews(articles: [NewsArticle], allowAI: Bool = false) async -> [HermesSummary] {
        var finalSummaries: [HermesSummary] = []
        var articlesToProcess: [NewsArticle] = []
        
        // 1. Check Cache
        for article in articles {
            if let cached = cache.getSummary(for: article.id) {
                // If we want to upgrade Lite to AI, we should check allowAI and cached.mode
                if allowAI && cached.mode == .lite {
                    articlesToProcess.append(article) // Re-process
                } else {
                    finalSummaries.append(cached)
                }
            } else {
                articlesToProcess.append(article)
            }
        }
        
        if articlesToProcess.isEmpty {
            return finalSummaries.sorted { $0.createdAt > $1.createdAt }
        }
        
        // 2. Decide Mode (Full vs Lite)
        if isLiteMode || !allowAI {
            // Skip AI. Per user request, we DO NOT fall back to Lite heuristics.
            // Only return already cached AI summaries (if any).
            // We do not save or generate Lite summaries anymore.
        } else {
            // Try Batch AI
            do {
                let batchedResults = try await llmService.analyzeBatch(articlesToProcess)
                finalSummaries.append(contentsOf: batchedResults)
                cache.saveSummaries(batchedResults)
            } catch {
                print("Hermes AI Error: \(error)")
                if case HermesError.quotaExhausted = error {
                    print("⚠️ Quota exhausted.")
                }
                
                // Fallback DISABLED per user request (If Groq fails, return 0/Empty)
                // We return empty results so Argus treats Hermes as unavailable (nil score)
            }
        }
        
        return finalSummaries.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Lite Mode Logic
    private func runLiteMode(articles: [NewsArticle]) -> [HermesSummary] {
        return articles.map { article in
            let text = (article.headline + " " + (article.summary ?? "")).lowercased()
            
            // Heuristics
            let positives = ["beats", "record", "all time high", "raises guidance", "strong demand", "profit", "up", "gain", "buy", "rekor", "kar", "büyüme"]
            let negatives = ["misses", "profit warning", "investigation", "downgrade", "cut", "loss", "down", "sell", "zarar", "düşüş", "kriz"]
            
            var score = 50
            var positiveCount = 0
            var negativeCount = 0
            
            for word in positives { if text.contains(word) { positiveCount += 1 } }
            for word in negatives { if text.contains(word) { negativeCount += 1 } }
            
            if positiveCount > negativeCount {
                score = Int.random(in: 60...80)
            } else if negativeCount > positiveCount {
                score = Int.random(in: 20...40)
            }
            
            // Messages
            let comment: String
            if score >= 60 { comment = "Hisse için kısa vadede olumlu bir haber (Lite Analiz)." }
            else if score <= 40 { comment = "Hisse için kısa vadede baskı oluşturabilecek olumsuz bir haber (Lite Analiz)." }
            else { comment = "Kısa vadede nötr bir haber (Lite Analiz)." }
            
            return HermesSummary(
                id: article.id,
                symbol: article.symbol,
                summaryTR: article.headline, // Lite mode uses headline as summary
                impactCommentTR: comment,
                impactScore: score,
                createdAt: Date(),
                mode: .lite
            )
        }
    }
    
    // Helper to get current mode
    func getCurrentMode() -> HermesMode {
        return isLiteMode ? .lite : .full
    }
    
    func resetQuota() {
        self.isLiteMode = false
    }
}
