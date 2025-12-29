import Foundation
import Combine

enum RadarSentiment: String, Codable {
    case positive = "POZİTİF"
    case negative = "NEGATİF"
    case neutral = "NÖTR"
}

struct RadarItem: Identifiable, Codable {
    let id: UUID
    let bankName: String
    let summary: String
    let sentiment: RadarSentiment
    let url: String
    let date: Date
    
    init(id: UUID, bankName: String, summary: String, sentiment: RadarSentiment, url: String, date: Date) {
        self.id = id
        self.bankName = bankName
        self.summary = summary
        self.sentiment = sentiment
        self.url = url
        self.date = date
    }
}

class RadarService: ObservableObject {
    static let shared = RadarService()
    
    // Target Banks
    private let targetBanks = ["Goldman Sachs", "Morgan Stanley", "JPMorgan", "Citi", "Citigroup", "BlackRock", "Bank of America", "Wells Fargo", "UBS", "Deutsche Bank"]
    
    // Keywords for Sentiment Proxy
    private let positiveKeywords = ["Upgrade", "Buy", "Outperform", "Bullish", "Higher", "Growth", "Record", "Strong", "Optimistic", "Rally", "Jump"]
    private let negativeKeywords = ["Downgrade", "Sell", "Underperform", "Bearish", "Lower", "Cut", "Weak", "Crash", "Drop", "Risk", "Inflation", "Recession"]
    
    // Focus Keywords
    private let strategyKeywords = ["Outlook", "Forecast", "Upgrade", "Strategy", "Prediction", "Target", "Rating", "Bull", "Bear"]

    private init() {}
    
    func fetchFeed() async -> [RadarItem] {
        // FMP Removed. Radar temporarily offline or needs migration to Finnhub.
        return []
    }
}
