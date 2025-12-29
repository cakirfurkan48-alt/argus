import Foundation
import SwiftUI

// MARK: - Chronos Models (Time Intelligence)

struct ChronosResult: Identifiable {
    let id = UUID()
    let symbol: String
    
    // 1. Trend Age (The Curse)
    let trendAgeDays: Int
    let ageVerdict: ChronosAgeVerdict
    
    // 2. Aroon Indicator (Trend Energy)
    let aroonUp: Double
    let aroonDown: Double
    
    // 3. Sequential (Exhaustion Counter)
    let sequentialCount: Int // Positive for Buy Setup (Green), Negative for Sell Setup (Red)
    let isSequentialComplete: Bool // true if 9 or 13 reached
    
    // 4. Time Safety Score (0-100)
    let timeScore: Double
    
    // Verdict
    var summary: String {
        return "Yaş: \(trendAgeDays) Gün | \(ageVerdict.rawValue)"
    }
}

enum ChronosAgeVerdict: String {
    case baby = "👶 YENİ DOĞAN (Güvensiz)"
    case prime = "💪 OLGUN (Güvenli)"
    case old = "👴 İHTİYAR (Riskli)"
    case ancient = "💀 LANETLİ (Uzak Dur)"
    case downtrend = "📉 Düşüş Trendi"
    case unknown = "❓ Belirsiz"
    
    var color: Color {
        switch self {
        case .baby: return .orange
        case .prime: return .green
        case .old: return .yellow
        case .ancient: return .red
        case .downtrend: return .gray
        case .unknown: return .gray
        }
    }
}
