import Foundation

// MARK: - Hermes Models

/// The mode in which Hermes is currently operating.
enum HermesMode: String, Codable {
    case full = "Full (AI)"
    case lite = "Lite (Offline)"
}

/// A processed summary of a news article, either from AI or Lite mode.
struct HermesSummary: Identifiable, Codable {
    let id: String // same as articleId
    let symbol: String
    
    // Content
    let summaryTR: String        // Türkçe özet
    let impactCommentTR: String  // Türkçe etki yorumu
    let impactScore: Int         // 0-100
    
    // Hermes v2.0 Context
    var relatedSectors: [String]? // e.g. ["Aviation", "Energy"]
    var rippleEffectScore: Int?   // 0-100 Impact on market/sectors
    
    // Metadata
    let createdAt: Date
    let mode: HermesMode
    
    // Computed helper for Color
    var impactColor: String {
        switch impactScore {
        case 80...100: return "Green"
        case 60..<80: return "Blue"
        case 40..<60: return "Gray"
        case 20..<40: return "Orange"
        default: return "Red"
        }
    }
}

/// DTO for Batch Gemini Response
struct HermesBatchResponse: Codable {
    let results: [HermesBatchItem]
}

struct HermesBatchItem: Codable {
    let id: String // Article ID to map back
    let summary_tr: String
    let impact_comment_tr: String
    let sentiment: String? // Added for validation (v2.2)
    let impact_score: Double
    let related_sectors: [String]
    let ripple_effect_score: Double
}

enum HermesError: Error {
    case quotaExhausted
    case apiError(Int)
    case parsingError
}
