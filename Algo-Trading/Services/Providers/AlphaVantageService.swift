import Foundation

/// Primary Provider for Macro Data (The Hydra: Head C)
class AlphaVantageService: DataProvider {
    static let shared = AlphaVantageService()
    var name: String { "Alpha Vantage" }
    
    private let baseURL = "https://www.alphavantage.co/query"
    
    private init() {}
    
    // MARK: - Macro
    func fetchMacroData() async throws -> MacroData {
        let cacheKey = "macro_global"
        // TTL: 12 Hours = 43200s (Macro data is slow moving)
        if let cached = DiskCacheService.shared.get(key: cacheKey, type: MacroData.self, maxAge: 43200) {
            return cached
        }
        
        // 1. Treasury Yield (10Y)
        async let bond10 = fetchTreasury(maturity: "10year")
        async let bond2 = fetchTreasury(maturity: "2year")
        
        // Note: AlphaVantage Free Tier doesn't have VIX or DXY directly usually.
        // We will return partial data and let MarketDataProvider fill the rest via Yahoo Backup.
        
        do {
            let (y10, y2) = try await (bond10, bond2)
            
            // For now, returning 0.0 for VIX/DXY to signal "Please Fetch Elsewhere" or "Missing"
            // MarketDataProvider should handle merging or fallback.
            let data = MacroData(vix: 0.0, bond10y: y10, bond2y: y2, dxy: 0.0, date: Date())
            
            // Only save to cache if we have complete data? 
            // Or save partial and let Merger handle it. 
            // Let's NOT save partial as complete.
            return data
        } catch {
            throw error
        }
    }
    
    private func fetchTreasury(maturity: String) async throws -> Double {
        let apiKey = Secrets.shared.alphaVantage
        let urlString = "\(self.baseURL)?function=TREASURY_YIELD&interval=daily&maturity=\(maturity)&apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // Use Centralized Heimdall Network (Auto Trace & Body Log)
        let data = try await HeimdallNetwork.request(
            url: url,
            engine: .aether,
            provider: .alphavantage,
            symbol: "US\(maturity)"
        )
        
        // Simple Parse: {"data": [{"value": "4.50", "date": "..."}]}
        struct AVIndicatorResponse: Decodable {
            let data: [AVIndicatorValue]?
            struct AVIndicatorValue: Decodable {
                let value: String
            }
        }
        
        let decoded = try JSONDecoder().decode(AVIndicatorResponse.self, from: data)
        if let valStr = decoded.data?.first?.value, let val = Double(valStr) {
            return val
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    private func fetchCPI(key: String) async throws -> Double {
        return 3.5 // Stub
    }
    
    // MARK: - Unused
    func fetchQuote(symbol: String) async throws -> Quote { throw URLError(.resourceUnavailable) }
    func fetchCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] { throw URLError(.resourceUnavailable) }
}
