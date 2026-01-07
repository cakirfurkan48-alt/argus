import Foundation

/// RateLimiter: API isteklerini sınırlayan actor.
/// Yahoo Finance ve diğer API'lerin rate limit aşımını önler.
/// Her istek arasında minimum bekleme süresi uygular.
actor RateLimiter {
    
    // MARK: - Singleton
    static let shared = RateLimiter()
    
    // MARK: - Configuration
    private let minInterval: TimeInterval = 0.2  // 200ms = 5 req/sec max
    private var lastRequestTime: Date = .distantPast
    private var requestCount: Int = 0
    private var windowStart: Date = Date()
    private let maxRequestsPerMinute: Int = 60
    
    private init() {}
    
    // MARK: - Public API
    
    /// İstek yapmadan önce bu fonksiyonu çağır.
    /// Rate limit aşılmışsa bekler, yoksa hemen döner.
    func waitIfNeeded() async {
        let now = Date()
        
        // Sliding window check
        if now.timeIntervalSince(windowStart) >= 60 {
            // Reset window
            windowStart = now
            requestCount = 0
        }
        
        // Check if we've exceeded the per-minute limit
        if requestCount >= maxRequestsPerMinute {
            let waitTime = 60 - now.timeIntervalSince(windowStart)
            if waitTime > 0 {
                print("⏳ RateLimiter: Minute limit reached, waiting \(Int(waitTime))s...")
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                windowStart = Date()
                requestCount = 0
            }
        }
        
        // Check minimum interval between requests
        let elapsed = now.timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            let waitTime = minInterval - elapsed
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        // Update tracking
        lastRequestTime = Date()
        requestCount += 1
    }
    
    /// Mevcut rate limit durumunu döndürür
    var status: String {
        return "Requests: \(requestCount)/\(maxRequestsPerMinute) per minute"
    }
    
    /// Rate limiter'ı sıfırla (test için)
    func reset() {
        lastRequestTime = .distantPast
        requestCount = 0
        windowStart = Date()
    }
}
