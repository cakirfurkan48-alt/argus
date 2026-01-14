import Foundation
import Combine

// MARK: - Argus Lab ViewModel (Argus 3.0)
/// UI verilerini ForwardTestLedger'dan çeker ve UI'a sunar.

@MainActor
class ArgusLabViewModel: ObservableObject {
    @Published var openTrades: [TradeRecord] = []
    @Published var closedTrades: [TradeRecord] = []
    @Published var lessons: [LessonRecord] = []
    @Published var isLoading = false
    
    func refresh() {
        isLoading = true
        
        Task {
            // Fetch from ledger
            openTrades = await ArgusLedger.shared.getOpenTrades()
            closedTrades = await ArgusLedger.shared.getClosedTrades(limit: 50)
            lessons = await ArgusLedger.shared.getLessons(limit: 50)
            isLoading = false
        }
    }
}

// MARK: - Data Models

struct TradeRecord: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let status: String // "OPEN" or "CLOSED"
    let entryDate: Date
    let entryPrice: Double
    let entryReason: String?
    let exitDate: Date?
    let exitPrice: Double?
    let pnlPercent: Double?
    let dominantSignal: String?
    let decisionId: String?
    
    // Computed
    var isOpen: Bool { status == "OPEN" }
}

struct LessonRecord: Identifiable, Codable {
    let id: UUID
    let tradeId: UUID
    let createdAt: Date
    let lessonText: String
    let deviationPercent: Double?
    let weightChanges: [String: Double]?
}
