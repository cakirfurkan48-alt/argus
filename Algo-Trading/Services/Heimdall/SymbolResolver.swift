import Foundation

/// "The Translator" - Resolves common symbol aliases to Provider-Specific tickers.
/// Especially for Yahoo Finance (e.g. SILVER -> SI=F).
struct SymbolResolver {
    static let shared = SymbolResolver()
    
    // Static Mappings
    private let yahooAliases: [String: String] = [
        "SILVER": "SI=F",
        "GOLD": "GC=F",
        "COPPER": "HG=F",
        "CRUDE_OIL": "CL=F",
        "OIL": "CL=F",
        "WTI": "CL=F",
        "CRUDE": "CL=F",
        "BRENT_OIL": "BZ=F",
        "BRENT": "BZ=F",
        "NAT_GAS": "NG=F",
        "VIX": "^VIX",
        "DXY": "DX-Y.NYB",
        "US10Y": "^TNX",
        "SPX": "^GSPC",
        "S&P500": "^GSPC",
        "SP500": "^GSPC",
        "NDX": "^IXIC",
        "DJI": "^DJI",
        "BTC": "BTC-USD",
        "ETH": "ETH-USD",
        "EURUSD": "EURUSD=X",
        "GBPUSD": "GBPUSD=X",
        "USDTRY": "USDTRY=X"
    ]
    
    /// Resolves `SILVER` to `SI=F` for Yahoo, or pass-through for others.
    func resolve(_ symbol: String, for provider: ProviderTag) -> String {
        let upper = symbol.uppercased()
        
        switch provider {
        case .yahoo: // Handle aliases
            if let alias = yahooAliases[upper] {
                print("🔁 SymbolAlias: \(symbol) -> \(alias) (Provider: \(provider.rawValue))")
                return alias
            }
            return upper
            
        case .eodhd:
            // EODHD mapping handles its own (e.g. .US suffix) in Provider, 
            // but if we had global aliases like SILVER, we could map here too.
            // EODHD usually standardizes differently, e.g. "SLV" ETF or Futures "SI.CMX"?
            // Keeping simple for now, relying on Provider's own mapSymbol logic.
            return upper
            
        default:
            return upper
        }
    }
}
