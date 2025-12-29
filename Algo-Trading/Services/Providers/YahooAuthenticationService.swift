import Foundation

/// Handles Yahoo Finance Authentication (Cookie & Crumb Management)
/// Solves "Invalid Crumb" (401) errors for v10 endpoints.
actor YahooAuthenticationService {
    static let shared = YahooAuthenticationService()
    
    private var crumb: String?
    private var cookie: String?
    private var lastAuthTime: Date?
    
    // Session with cookie storage
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    func getCrumb() async throws -> (String, String) {
        // 1. Check Cache (1 Hour TTL)
        if let c = crumb, let k = cookie, let t = lastAuthTime, -t.timeIntervalSinceNow < 3600 {
            return (c, k)
        }
        
        // 2. Refresh
        return try await refresh()
    }
    
    private func refresh() async throws -> (String, String) {
        print("🔐 YahooAuth: Refreshing Crumb & Cookie...")
        
        // Step A: Get Cookie from main page or FC
        let fcURL = URL(string: "https://fc.yahoo.com")!
        var req = URLRequest(url: fcURL)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await session.data(for: req)
        
        guard (response as? HTTPURLResponse) != nil else {
             throw URLError(.badServerResponse)
        }
        
        // Extract Cookie from Session Storage (more reliable than manual header parsing due to redirects)
        guard let cookies = session.configuration.httpCookieStorage?.cookies(for: fcURL), !cookies.isEmpty else {
            // Fallback: Try manual header (sometimes needed if storage fails)
            // But usually session handles it.
            // If FC fails, we might try "https://finance.yahoo.com"
            print("⚠️ YahooAuth: No cookies from FC. Retrying with homepage.")
             try await Task.sleep(nanoseconds: 500_000_000)
            return try await refreshFromHomepage()
        }
        
        // Step B: Get Crumb
        // Now that we have cookies in the session, call getcrumb
        let crumbURL = URL(string: "https://query1.finance.yahoo.com/v1/test/getcrumb")!
        var crumbReq = URLRequest(url: crumbURL)
        crumbReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let (data, crumbResp) = try await session.data(for: crumbReq)
        
        guard let cResp = crumbResp as? HTTPURLResponse, cResp.statusCode == 200 else {
            print("⚠️ YahooAuth: Crumb failed (HTTP \((crumbResp as? HTTPURLResponse)?.statusCode ?? 0))")
             throw URLError(.userAuthenticationRequired)
        }
        
        guard let crumbString = String(data: data, encoding: .utf8), !crumbString.isEmpty else {
             throw URLError(.cannotParseResponse)
        }
        
        self.crumb = crumbString
        // Extract generic cookie string for headers ("A=...; B=...")
        self.cookie = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        self.lastAuthTime = Date()
        
        print("✅ YahooAuth: Acquired Crumb [\(crumbString)]")
        return (crumbString, self.cookie!)
    }
    
    private func refreshFromHomepage() async throws -> (String, String) {
         let url = URL(string: "https://finance.yahoo.com")!
         let req = URLRequest(url: url)
         let (_, _) = try await session.data(for: req)
         
         // Now try getcrumb
         let crumbURL = URL(string: "https://query1.finance.yahoo.com/v1/test/getcrumb")!
         var crumbReq = URLRequest(url: crumbURL)
         crumbReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
         
         let (data, _) = try await session.data(for: crumbReq)
         guard let s = String(data: data, encoding: .utf8), !s.isEmpty else {
             throw URLError(.userAuthenticationRequired)
         }
         
         self.crumb = s
         if let cookies = session.configuration.httpCookieStorage?.cookies(for: url) {
             self.cookie = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
         }
         self.lastAuthTime = Date()
         return (s, self.cookie ?? "")
    }
}
