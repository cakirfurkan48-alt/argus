import Foundation

// MARK: - XML Parser Delegate for RSS
class RSSParser: NSObject, XMLParserDelegate {
    private var articles: [NewsArticle] = []
    private var currentElement = ""
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentDescription: String = ""
    private var currentPubDate: String = ""
    
    // Limits
    private let limit: Int
    
    init(limit: Int) {
        self.limit = limit
    }
    
    func parse(data: Data) -> [NewsArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }
    
    // MARK: - XMLParserDelegate Methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            if articles.count < limit {
                // Parse Date
                let formatter = DateFormatter()
                formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z" // Standard RSS Date Format
                // Investing.com might vary, but this is standard
                let date = formatter.date(from: currentPubDate) ?? Date()
                
                let article = NewsArticle(
                    id: UUID().uuidString,
                    symbol: "MARKET", // General
                    source: "Investing.com",
                    headline: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                    publishedAt: date
                )
                articles.append(article)
            }
        }
    }
}

// MARK: - RSSNewsProvider
final class RSSNewsProvider: NewsProvider {
    // Investing.com Turkey Feeds
    private let feedURLs: [String: String] = [
        "GENERAL": "https://tr.investing.com/rss/news_25.rss", // Genel Haberler
        "FOREX": "https://tr.investing.com/rss/news_1.rss",   // Döviz
        "STOCK": "https://tr.investing.com/rss/news_285.rss", // Hisse Senedi
        "CRYPTO": "https://tr.investing.com/rss/news_301.rss", // Kripto
        "ANALYSIS": "https://tr.investing.com/rss/market_overview.rss" // Piyasa Analizleri
    ]
    
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle] {
        // Decide which feed to use
        let feedKey: String
        if symbol == "GENERAL" || symbol == "MARKET" {
            feedKey = "GENERAL"
        } else if symbol.contains("USD") || symbol.contains("EUR") {
            feedKey = "FOREX"
        } else if symbol.contains("BTC") || symbol.contains("ETH") {
            feedKey = "CRYPTO"
        } else {
             // For specific Stocks, RSS is just "General Stock News", NOT "Specific AAPL News".
             // Returning General Stock News for "AAPL" is misleading (Duplicate News Issue).
             // We should ONLY return this if explicitly asked for "STOCK_MARKET".
             // If asked for "AAPL", we should return [] if no specific source available,
             // rather than filling it with random Turkish stock news.
             return []
        }
        
        guard let urlStr = feedURLs[feedKey], let url = URL(string: urlStr) else {
            return []
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("application/rss+xml, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("RSS HTTP Status: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let parser = RSSParser(limit: limit)
            let parsed = parser.parse(data: data)
            
            if parsed.isEmpty {
                 throw URLError(.cancelled)
            }
            
            // Success: Save to Cache
            DataCacheService.shared.save(value: parsed, kind: .news, symbol: symbol, source: "Investing.com")
            
            return parsed
        } catch {
            print("RSS Fetch Failed: \(error). Checking cache...")
            
            // Fallback to Cache
            if let entry = await DataCacheService.shared.getEntry(kind: .news, symbol: symbol),
               let articles = try? JSONDecoder().decode([NewsArticle].self, from: entry.data) {
                print("💾 Using Cached News for \(symbol) from \(entry.source)")
                return articles
            }
            
            // If No Cache, return Error Mock
            return [
                NewsArticle(
                    id: UUID().uuidString,
                    symbol: "MARKET",
                    source: "Investing.com (Error)",
                    headline: "Piyasa Verileri Alınamadı",
                    summary: "İnternet bağlantınızı kontrol edin. Önbellekte veri bulunamadı. Hata: \(error.localizedDescription)",
                    url: "https://tr.investing.com",
                    publishedAt: Date()
                )
            ]
        }
    }
}
