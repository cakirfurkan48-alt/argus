import Foundation

// MARK: - Forward Test Result
/// Bir karar veya tahminin doğrulanmış sonucu
struct ForwardTestResult: Codable, Identifiable, Sendable {
    let id: UUID
    let symbol: String
    let testType: ForwardTestType
    let eventDate: Date          // Kararın verildiği tarih
    let verificationDate: Date    // Doğrulama yapıldığı tarih
    
    // Orijinal Tahmin
    let originalPrice: Double
    let predictedPrice: Double?   // Prometheus için
    let predictedAction: String?  // Argus için (BUY/SELL/HOLD)
    
    // Gerçekleşen
    let actualPrice: Double
    let actualChange: Double      // Yüzde değişim
    
    // Sonuç
    let wasCorrect: Bool
    let accuracy: Double          // 0-100 (tahmin ne kadar yakın)
    
    // Metadata
    let moduleScores: [String: Double]?  // Karar anındaki modül skorları
    let notes: String?
}

enum ForwardTestType: String, Codable, Sendable {
    case prometheusforecast = "prometheus"  // 5 günlük fiyat tahmini
    case argusDecision = "argus"            // BUY/SELL/HOLD kararı
}

// MARK: - Processing Statistics
struct ForwardTestStats: Codable, Sendable {
    let totalTests: Int
    let correctTests: Int
    let hitRate: Double           // correctTests / totalTests
    let averageAccuracy: Double   // Ortalama accuracy
    
    // Tip bazlı
    let prometheusHitRate: Double
    let argusHitRate: Double
    
    // En son güncelleme
    let lastUpdated: Date
    
    static var empty: ForwardTestStats {
        ForwardTestStats(
            totalTests: 0,
            correctTests: 0,
            hitRate: 0,
            averageAccuracy: 0,
            prometheusHitRate: 0,
            argusHitRate: 0,
            lastUpdated: Date()
        )
    }
}

// MARK: - Pending Event (İşlenmeyi bekleyen)
struct PendingForwardTest: Codable, Identifiable, Sendable {
    let id: String                // event_id from database
    let symbol: String
    let testType: ForwardTestType
    let eventDate: Date
    let originalPrice: Double
    let predictedPrice: Double?
    let predictedAction: String?
    let daysUntilMature: Int      // Kaç gün kaldı doğrulamaya
    
    var isMature: Bool {
        daysUntilMature <= 0
    }
}

// MARK: - Event Data Types (For Ledger Queries)
struct ForecastEventData: Sendable {
    let eventId: String
    let symbol: String
    let eventDate: Date
    let currentPrice: Double
    let predictedPrice: Double
}

struct DecisionEventData: Sendable {
    let eventId: String
    let symbol: String
    let eventDate: Date
    let currentPrice: Double
    let action: String
    let moduleScores: [String: Double]
}
