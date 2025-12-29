import Foundation
import Combine

/// Service to fetch "Smart Money" signals (Analysts & Insiders)
/// Implements strict 14-Day Disk Cache to preserve API limits.
final class IntelligenceService {
    static let shared = IntelligenceService()
    
    private init() {}
    
    // MARK: - Constants
    private let cacheValidSeconds: TimeInterval = 1_209_600 // 14 Days
    private let insiderLookbackDays = 90
    
    // MARK: - Public API
    
    /// Fetches intelligence data, using cache if available and valid.
    /// - Parameter symbol: Stock symbol (e.g. "AAPL")
    /// - Parameter isETF: If true, returns nil immediately (No-Op).
    func fetchIntelligence(symbol: String, isETF: Bool) async throws -> MarketIntelligenceSnapshot? {
        // 1. ETF Guard
        if isETF { return nil }
        
        // 2. Check Cache
        if let cached = loadFromCache(symbol: symbol) {
            print("🧠 IntelligenceService: Cache Hit for \(symbol)")
            return cached
        }
        
        // 3. Fetch Fresh Data (The Hydra Approach)
        print("🧠 IntelligenceService: Fetching Fresh for \(symbol)")
        let snapshot = try await fetchFreshData(symbol: symbol)
        
        // 4. Save to Cache
        saveToCache(snapshot)
        
        return snapshot
    }
    
    // MARK: - Fetching Logic
    
    private func fetchFreshData(symbol: String) async throws -> MarketIntelligenceSnapshot {
        // We run both fetches in parallel for speed, though they are independent.
        // Step A: Analyst Data (Yahoo)
        async let yahooTask = fetchYahooAnalystData(symbol: symbol)
        
        // Step B: Insider Data (Finnhub)
        async let finnhubTask = fetchFinnhubInsiderData(symbol: symbol)
        
        let (analystData, insiderData) = try await (yahooTask, finnhubTask)
        
        return MarketIntelligenceSnapshot(
            symbol: symbol,
            fetchDate: Date(),
            targetMeanPrice: analystData.targetMeanPrice,
            recommendationMean: analystData.recommendationMean,
            netInsiderBuySentiment: insiderData.netSentiment,
            lastInsiderTransactionDate: insiderData.lastDate
        )
    }
    
    // MARK: - Step A: Yahoo Finance (Analysts)
    
    private struct AnalystResult {
        let targetMeanPrice: Double?
        let recommendationMean: Double?
    }
    
    private func fetchYahooAnalystData(symbol: String) async throws -> AnalystResult {
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return AnalystResult(targetMeanPrice: nil, recommendationMean: nil)
        }
        
        // Endpoint: quoteSummary with modules=financialData
        let urlString = "https://query2.finance.yahoo.com/v10/finance/quoteSummary/\(encodedSymbol)?modules=financialData"
        guard let url = URL(string: urlString) else {
            return AnalystResult(targetMeanPrice: nil, recommendationMean: nil)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(MarketIntelligenceSnapshot.YahooQuoteSummaryResponse.self, from: data)
            
            if let finData = response.quoteSummary.result?.first?.financialData {
                return AnalystResult(
                    targetMeanPrice: finData.targetMeanPrice?.raw,
                    recommendationMean: finData.recommendationMean?.raw
                )
            }
        } catch {
            print("⚠️ IntelligenceService: Yahoo Fetch Error for \(symbol): \(error)")
        }
        
        return AnalystResult(targetMeanPrice: nil, recommendationMean: nil)
    }
    
    // MARK: - Step B: Finnhub (Insiders)
    
    private struct InsiderResult {
        let netSentiment: Double
        let lastDate: Date?
    }
    
    private func fetchFinnhubInsiderData(symbol: String) async throws -> InsiderResult {
        let apiKey = Secrets.shared.finnhub
        let urlString = "https://finnhub.io/api/v1/stock/insider-sentiment?symbol=\(symbol)&from=2020-01-01&token=\(apiKey)" // 'from' creates a wide enough window, we filter manually
        
        guard let url = URL(string: urlString) else {
            return InsiderResult(netSentiment: 0.0, lastDate: nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(MarketIntelligenceSnapshot.FinnhubInsiderSentimentResponse.self, from: data)
            
            guard let entries = response.data, !entries.isEmpty else {
                return InsiderResult(netSentiment: 0.0, lastDate: nil)
            }
            
            // Filter: Last 90 Days Only // Actually user said 90 days.
            // But Finnhub returns monthly data.
            // We'll mimic 90 days by taking the last 3 months of data if available.
            
            let calendar = Calendar.current
            let threeMonthsAgo = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            
            var netChange = 0.0
            var latestDate: Date? = nil
            
            for entry in entries {
                // Construct date from Year/Month (Finnhub gives month 1-12)
                var components = DateComponents()
                components.year = entry.year
                components.month = entry.month
                components.day = 1
                
                if let date = calendar.date(from: components) {
                    if date >= threeMonthsAgo {
                        netChange += entry.change
                        
                        // Track latest
                        if latestDate == nil || date > latestDate! {
                            latestDate = date
                        }
                    }
                }
            }
            
            return InsiderResult(netSentiment: netChange, lastDate: latestDate)
            
        } catch {
            print("⚠️ IntelligenceService: Finnhub Fetch Error for \(symbol): \(error)")
        }
        
        return InsiderResult(netSentiment: 0.0, lastDate: nil)
    }
    
    // MARK: - Caching Logic (FileManager)
    
    private func getCacheURL(symbol: String) -> URL? {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        // Ensure directory exists? Standard Caches always exists on iOS/Mac apps.
        return cacheDir.appendingPathComponent("intelligence_\(symbol).json")
    }
    
    private func loadFromCache(symbol: String) -> MarketIntelligenceSnapshot? {
        guard let url = getCacheURL(symbol: symbol) else { return nil }
        
        do {
            // Check availability
            if !FileManager.default.fileExists(atPath: url.path) { return nil }
            
            // Check Age
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                if Date().timeIntervalSince(modificationDate) > cacheValidSeconds {
                    // Expired
                    try? FileManager.default.removeItem(at: url)
                    return nil
                }
            }
            
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(MarketIntelligenceSnapshot.self, from: data)
            return snapshot
        } catch {
            return nil
        }
    }
    
    private func saveToCache(_ snapshot: MarketIntelligenceSnapshot) {
        guard let url = getCacheURL(symbol: snapshot.symbol) else { return }
        
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url)
        } catch {
            print("⚠️ IntelligenceService: Cache Write Error: \(error)")
        }
    }
}
