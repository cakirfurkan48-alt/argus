import Foundation

/// "The Gatekeeper" - SIMPLIFIED Yahoo-Only Mode
/// All routing complexity removed. Direct Yahoo Finance calls.
@MainActor
final class HeimdallOrchestrator {
    static let shared = HeimdallOrchestrator()
    
    private let yahoo = YahooFinanceProvider.shared
    private let fred = FredProvider.shared
    
    private init() {
        print("🏛️ HEIMDALL: Yahoo Direct Mode initialized")
    }
    
    // MARK: - Quote
    
    func requestQuote(symbol: String, context: UsageContext = .interactive) async throws -> Quote {
        // BIST Routing (BorsaPy)
        // BIST Routing REMOVED: BorsaPy returns incorrect data.
        // Unified path -> Yahoo Finance (which has correct BIST data)
        // if symbol.uppercased().hasSuffix(".IS") ... { ... }
        
        await RateLimiter.shared.waitIfNeeded()
        print("🏛️ Yahoo Direct: Quote for \(symbol)")
        return try await yahoo.fetchQuote(symbol: symbol)
    }
    
    // MARK: - Fundamentals
    
    func requestFundamentals(symbol: String, context: UsageContext = .interactive) async throws -> FinancialsData {
        await RateLimiter.shared.waitIfNeeded()
        print("🏛️ Yahoo Direct: Fundamentals for \(symbol)")
        return try await yahoo.fetchFundamentals(symbol: symbol)
    }
    
    // MARK: - Candles
    
    func requestCandles(
        symbol: String,
        timeframe: String,
        limit: Int,
        context: UsageContext = .interactive,
        provider: ProviderTag? = nil,
        instrument: CanonicalInstrument? = nil
    ) async throws -> [Candle] {
        // BIST Routing (BorsaPy)
        // BIST Routing REMOVED for Data Consistency
        // BorsaPy candles are OK but we want unified provider.
        // if (symbol.uppercased().hasSuffix(".IS") ... { ... }
        
        await RateLimiter.shared.waitIfNeeded()
        print("🏛️ Yahoo Direct: Candles for \(symbol) (\(timeframe), \(limit) bars)")
        return try await yahoo.fetchCandles(symbol: symbol, timeframe: timeframe, limit: limit)
    }
    
    // MARK: - News
    
    func requestNews(symbol: String, limit: Int = 10, context: UsageContext = .interactive) async throws -> [NewsArticle] {
        await RateLimiter.shared.waitIfNeeded()
        print("🏛️ Yahoo Direct: News for \(symbol)")
        return try await yahoo.fetchNews(symbol: symbol)
    }
    
    // MARK: - Screener (Phoenix)
    
    func requestScreener(type: ScreenerType, limit: Int = 10) async throws -> [Quote] {
        await RateLimiter.shared.waitIfNeeded()
        print("🏛️ Yahoo Direct: Screener \(type)")
        return try await yahoo.fetchScreener(type: type, limit: limit)
    }
    
    // MARK: - Macro
    
    func requestMacro(symbol: String, context: UsageContext = .interactive) async throws -> HeimdallMacroIndicator {
        // Routing Logic
        if symbol.hasPrefix("FRED.") || ["INFLATION", "FEDFUNDS", "GDP", "UNRATE"].contains(symbol) {
            // Map common aliases to FRED Series IDs
            let seriesId: String
            switch symbol {
            case "INFLATION": seriesId = "CPIAUCSL"
            case "FEDFUNDS": seriesId = "FEDFUNDS"
            case "GDP": seriesId = "GDPC1"
            case "UNRATE": seriesId = "UNRATE"
            default: seriesId = symbol.replacingOccurrences(of: "FRED.", with: "")
            }
            
            print("🏛️ HEIMDALL: Routing \(symbol) -> FRED Provider (\(seriesId))")
            
            // Fetch series from Fred
            let series = try await fred.fetchSeries(seriesId: seriesId, limit: 1)
            guard let latest = series.first else { throw URLError(.badServerResponse) }
            
            return HeimdallMacroIndicator(
                symbol: symbol,
                value: latest.1,
                change: nil,
                changePercent: nil,
                lastUpdated: latest.0
            )
        } else {
            // Default to Yahoo (VIX, DXY, Etc)
            print("🏛️ HEIMDALL: Routing \(symbol) -> Yahoo Provider")
            return try await yahoo.fetchMacro(symbol: symbol)
        }
    }
    
    // MARK: - FRED Series (Special - Direct to FRED)
    
    func requestMacroSeries(instrument: CanonicalInstrument, limit: Int = 24) async throws -> [(Date, Double)] {
        guard let seriesId = instrument.fredSeriesId else {
            throw HeimdallCoreError(category: .symbolNotFound, code: 404, message: "No FRED Series ID for \(instrument.internalId)", bodyPrefix: "")
        }
        print("🏛️ FRED Direct: Series \(seriesId)")
        return try await fred.fetchSeries(seriesId: seriesId, limit: limit)
    }
    
    func requestFredSeries(series: FredProvider.SeriesInfo, limit: Int = 24) async throws -> [(Date, Double)] {
        print("🏛️ FRED Direct: Series \(series.rawValue)")
        return try await fred.fetchSeries(seriesId: series.rawValue, limit: limit)
    }
    
    // MARK: - Instrument Candles
    
    func requestInstrumentCandles(instrument: CanonicalInstrument, timeframe: String = "1D", limit: Int = 60) async throws -> [Candle] {
        if instrument.internalId == "macro.trend" {
            throw HeimdallCoreError(category: .unknown, code: 400, message: "Cannot fetch candles for derived (TREND)", bodyPrefix: "")
        }
        return try await requestCandles(symbol: instrument.internalId, timeframe: timeframe, limit: limit, instrument: instrument)
    }
    
    // MARK: - System Health
    
    enum SystemHealthStatus: String {
        case operational = "Operational"
        case degraded = "Degraded"
        case critical = "Critical - DO NOT TRADE"
    }
    
    func checkSystemHealth() async -> SystemHealthStatus {
        // Simple: Try a test quote
        do {
            _ = try await yahoo.fetchQuote(symbol: "SPY")
            return .operational
        } catch {
            return .critical
        }
    }
    
    func getProviderScores() async -> [String: ProviderScore] {
        return ["Yahoo": ProviderScore.neutral]
    }
}

// MARK: - Usage Context (required for API compatibility)
enum UsageContext {
    case interactive
    case background
    case realtime
}

