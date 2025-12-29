import Foundation

/// Persistent Telemetry Store for Chiron Learning.
/// Manages writing TradeSnapshots to disk for future AI training.
actor TradeJournal {
    static let shared = TradeJournal()
    
    private let fileName = "chiron_trade_journal.json"
    private var snapshots: [TradeSnapshot] = []
    
    private init() {
        // Load Snapshots inline to avoid actor isolation issues in init
        let fName = "chiron_trade_journal.json"
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docDir.appendingPathComponent(fName)
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                self.snapshots = try JSONDecoder().decode([TradeSnapshot].self, from: data)
            } catch {
                print("⚠️ Chiron Journal Load Failed (Starting New): \(error)")
            }
        }
    }
    
    // MARK: - Public API
    
    func logEntry(snapshot: TradeSnapshot) {
        snapshots.append(snapshot)
        saveSnapshots()
        print("🏛️ Chiron Journal: New Entry Logged for \(snapshot.symbol) (ID: \(snapshot.tradeId.uuidString.prefix(4)))")
    }
    
    func logExit(tradeId: UUID, exitPrice: Double, exitDate: Date, exitReason: String) {
        guard let index = snapshots.firstIndex(where: { $0.tradeId == tradeId }) else {
            print("⚠️ Chiron Journal: Cannot find open trade for exit log (ID: \(tradeId))")
            return
        }
        
        var snap = snapshots[index]
        snap.exitPrice = exitPrice
        snap.exitDate = exitDate
        snap.exitReason = exitReason
        
        // Calculate PnL (Long only logic for now)
        let diff = exitPrice - snap.entryPrice
        let pnlPct = (diff / snap.entryPrice) * 100.0
        snap.pnlPercent = pnlPct
        
        snap.timeInTradeSec = exitDate.timeIntervalSince(snap.entryDate)
        
        // NOTE: MFE/MAE requires intraday tracking which is heavy. 
        // For MVP, we skip intricate MFE/MAE calculation here, 
        // or calculate it roughly if we had high-low history passed in.
        // Leaving nil for now.
        
        snapshots[index] = snap
        saveSnapshots()
        print("🏛️ Chiron Journal: Exit Logged for \(snap.symbol). PnL: %\(String(format: "%.2f", pnlPct))")
    }
    
    // MARK: - Persistence
    
    private func getFileURL() -> URL? {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docDir.appendingPathComponent(fileName)
    }
    
    private func saveSnapshots() {
        guard let url = getFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: url)
        } catch {
            print("❌ Chiron Journal Save Failed: \(error)")
        }
    }
    

    
    // MARK: - Analytics
    
    func getWinRate() -> Double {
        let closed = snapshots.filter { $0.exitPrice != nil }
        guard !closed.isEmpty else { return 0.0 }
        let wins = closed.filter { ($0.pnlPercent ?? 0) > 0 }.count
        return Double(wins) / Double(closed.count) * 100.0
    }
}
