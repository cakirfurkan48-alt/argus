import Foundation

class MarketStackProvider {
    static let shared = MarketStackProvider()
    
    private let apiKey = Secrets.marketStackKey
    private let baseURL = "http://api.marketstack.com/v1"
    
    private init() {}
    
    func fetchEOD(symbol: String) async throws -> MarketStackEOD? {
        // MarketStack sometimes requires exchange suffix or special handling
        let urlString = "\(baseURL)/eod?access_key=\(apiKey)&symbols=\(symbol)&limit=1"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MarketStackResponse.self, from: data)
        return response.data.first
    }
}

struct MarketStackResponse: Codable {
    let data: [MarketStackEOD]
}

struct MarketStackEOD: Codable {
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double?
    let volume: Double?
    let adj_high: Double?
    let adj_low: Double?
    let adj_close: Double?
    let adj_open: Double?
    let adj_volume: Double?
    let split_factor: Double?
    let dividend: Double?
    let symbol: String?
    let exchange: String?
    let date: String?
}
