import Foundation

class TiingoProvider {
    static let shared = TiingoProvider()
    
    private let apiKey = Secrets.tiingoKey
    private let baseURL = "https://api.tiingo.com/tiingo"
    
    private init() {}
    
    func fetchMeta(symbol: String) async throws -> TiingoMeta? {
        let urlString = "\(baseURL)/daily/\(symbol)?token=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(TiingoMeta.self, from: data)
    }
}

struct TiingoMeta: Codable {
    let ticker: String
    let name: String?
    let description: String?
    let startDate: String?
    let endDate: String?
    let exchangeCode: String?
}
