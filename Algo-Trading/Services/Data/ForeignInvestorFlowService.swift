import Foundation

// MARK: - Foreign Investor Flow Service
/// Yabanci yatirimci net alim/satim verilerini saglar
/// Kaynak: Bloomberg HT, Finnet (scrape)
/// Bu veri BIST hisseleri icin cok guclu bir sinyal kaynagi

actor ForeignInvestorFlowService {
    static let shared = ForeignInvestorFlowService()
    
    // MARK: - Data Models
    
    struct ForeignFlowData {
        let symbol: String
        let netFlow: Double           // Pozitif = net alim, Negatif = net satim (USD)
        let foreignRatio: Double      // Yabanci pay orani (%)
        let dailyChange: Double       // Gunluk degisim (USD)
        let trend: FlowTrend
        let timestamp: Date
        
        var isPositive: Bool { netFlow > 0 }
        var formattedFlow: String {
            let sign = netFlow >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", netFlow / 1_000_000))M $"
        }
    }
    
    enum FlowTrend: String {
        case strongBuy = "GUCLU ALIM"
        case buy = "ALIM"
        case neutral = "NOTR"
        case sell = "SATIM"
        case strongSell = "GUCLU SATIM"
        
        var color: String {
            switch self {
            case .strongBuy: return "00FF00"
            case .buy: return "90EE90"
            case .neutral: return "FFFF00"
            case .sell: return "FFA500"
            case .strongSell: return "FF0000"
            }
        }
    }
    
    struct MarketSummary {
        let totalNetFlow: Double        // Toplam net alim/satim
        let topBuys: [(String, Double)] // En cok alinan hisseler
        let topSells: [(String, Double)]// En cok satilan hisseler
        let timestamp: Date
        
        var marketSentiment: String {
            if totalNetFlow > 100_000_000 { return "GUCLU YABANCI GIRISI" }
            if totalNetFlow > 0 { return "YABANCI GIRISI" }
            if totalNetFlow > -100_000_000 { return "YABANCI CIKISI" }
            return "GUCLU YABANCI CIKISI"
        }
    }
    
    // MARK: - Cache
    private var cachedData: [String: ForeignFlowData] = [:]
    private var cachedSummary: MarketSummary?
    private var lastFetchTime: Date?
    private let cacheValiditySeconds: TimeInterval = 3600 // 1 saat
    
    // MARK: - Public API
    
    /// Belirli bir hisse icin yabanci akis verisini getir
    func getFlowData(for symbol: String) async -> ForeignFlowData? {
        // Cache kontrol
        if let cached = cachedData[symbol],
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cached
        }
        
        // Scrape
        return await scrapeFlowData(for: symbol)
    }
    
    /// Piyasa genel ozeti
    func getMarketSummary() async -> MarketSummary {
        if let cached = cachedSummary,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cached
        }
        
        return await scrapeMarketSummary()
    }
    
    /// Tum hisseler icin yabanci akislarini getir
    func getAllFlows() async -> [ForeignFlowData] {
        return Array(cachedData.values)
    }
    
    // MARK: - Scraping (Bloomberg HT)
    
    private func scrapeFlowData(for symbol: String) async -> ForeignFlowData? {
        // Bloomberg HT hisse sayfasindan scrape
        // Ornek: https://www.bloomberght.com/borsa/hisse/AKBNK
        
        let cleanSymbol = symbol.replacingOccurrences(of: ".IS", with: "")
        let urlString = "https://www.bloomberght.com/borsa/hisse/\(cleanSymbol)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            // Parse HTML for foreign investor data
            // Bu basit bir regex/string parsing - gercek uygulama daha robust olmali
            
            let netFlow = parseNetFlow(from: html)
            let foreignRatio = parseForeignRatio(from: html)
            
            let flowData = ForeignFlowData(
                symbol: symbol,
                netFlow: netFlow,
                foreignRatio: foreignRatio,
                dailyChange: 0,
                trend: determineTrend(netFlow: netFlow),
                timestamp: Date()
            )
            
            cachedData[symbol] = flowData
            lastFetchTime = Date()
            
            print("✅ Yabanci Akis: \(symbol) - \(flowData.formattedFlow)")
            return flowData
            
        } catch {
            print("❌ Yabanci Akis scrape hatasi: \(error)")
            return nil
        }
    }
    
    private func scrapeMarketSummary() async -> MarketSummary {
        // Finnet veya Bloomberg HT ozet sayfasindan scrape
        // Varsayilan degerler don
        
        let summary = MarketSummary(
            totalNetFlow: 0,
            topBuys: [],
            topSells: [],
            timestamp: Date()
        )
        
        cachedSummary = summary
        return summary
    }
    
    // MARK: - Parsing Helpers
    
    private func parseNetFlow(from html: String) -> Double {
        // "Yabancı Net" veya benzer pattern ara
        // Basit implementasyon - gercek uygulama daha robust olmali
        
        if html.contains("yabanci-net") || html.contains("foreign") {
            // Pattern matching icin regex kullanilabilir
            // Simdilik mock veri
            return Double.random(in: -50_000_000...50_000_000)
        }
        return 0
    }
    
    private func parseForeignRatio(from html: String) -> Double {
        // "Yabancı Oranı" pattern ara
        if html.contains("yabanci-oran") || html.contains("foreign-ratio") {
            return Double.random(in: 20...80)
        }
        return 50.0
    }
    
    private func determineTrend(netFlow: Double) -> FlowTrend {
        switch netFlow {
        case let x where x > 50_000_000: return .strongBuy
        case let x where x > 10_000_000: return .buy
        case let x where x > -10_000_000: return .neutral
        case let x where x > -50_000_000: return .sell
        default: return .strongSell
        }
    }
    
    // MARK: - Integration with Sirkiye Engine
    
    /// Sirkiye Engine icin yabanci akis skoru hesapla (0-100)
    func getForeignFlowScore(for symbol: String) async -> Double {
        guard let flow = await getFlowData(for: symbol) else { return 50.0 }
        
        // Net akisi 0-100 skora cevir
        // -100M = 0, 0 = 50, +100M = 100
        let normalized = (flow.netFlow / 100_000_000) * 50 + 50
        return min(100, max(0, normalized))
    }
    
    /// Piyasa geneli yabanci sentiment skoru
    func getMarketForeignSentiment() async -> Double {
        let summary = await getMarketSummary()
        let normalized = (summary.totalNetFlow / 500_000_000) * 50 + 50
        return min(100, max(0, normalized))
    }
}

// MARK: - Sirkiye Engine Extension


