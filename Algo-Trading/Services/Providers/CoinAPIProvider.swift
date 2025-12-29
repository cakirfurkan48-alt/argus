import Foundation

class CoinAPIProvider: DataProvider {
    static let shared = CoinAPIProvider()
    var name: String { "CoinAPI" }
    
    private let apiKey = "f53468d0-3ad4-439f-bb36-e8507917a300"
    private let baseURL = "https://rest.coinapi.io/v1"
    
    private init() {}
    
    func fetchQuote(symbol: String) async throws -> Quote {
        // CoinAPI expects "BTC/USD" -> "BTC" usually for assets, or specific symbols.
        // Assuming symbol mapping handles it or we pass raw.
        // Endpoint: /exchangerate/BTC/USD
        
        let assetId = symbol.replacingOccurrences(of: "USD", with: "") // Basic cleaning
        let urlString = "\(baseURL)/exchangerate/\(assetId)/USD"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-CoinAPI-Key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct CoinRate: Codable {
            let time: String
            let asset_id_base: String
            let asset_id_quote: String
            let rate: Double
        }
        
        let r = try JSONDecoder().decode(CoinRate.self, from: data)
        
        // CoinAPI Exchange Rate doesn't give 24h change directly in this endpoint.
        // We'd need OHLCV. For now, assuming 0 change or fetch OHLC.
        // Let's return price only.
        return Quote(c: r.rate, d: 0, dp: 0, currency: "USD")
    }
    
    func fetchCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        throw URLError(.resourceUnavailable)
    }
}
