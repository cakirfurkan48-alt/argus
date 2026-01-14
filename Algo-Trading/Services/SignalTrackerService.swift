import Foundation
import Combine

/// Service to manage "Argus Journal" (Forward Testing).
/// Uses File System (Documents/ArgusJournal) for persistence.
final class SignalTrackerService: ObservableObject, @unchecked Sendable {
    static let shared = SignalTrackerService()
    
    @Published var journalEntries: [JournalEntry] = []
    
    private let fileManager = FileManager.default
    private let indexFileName = "journal_index.json"
    private var journalDirectory: URL? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documents.appendingPathComponent("ArgusJournal")
    }
    
    private init() {
        createDirectoryIfNeeded()
        loadIndex()
    }
    
    // MARK: - Core Actions
    
    /// Snapshots the current decision and adds it to the journal.
    /// Snapshots the current decision and manages trade lifecycle (Open/Close).
    func trackSignal(
        symbol: String,
        price: Double,
        decision: ArgusDecisionResult
    ) {
        guard let journalDir = journalDirectory else { return }
        
        let newAction = decision.finalActionCore.rawValue.uppercased() // "BUY", "SELL"
        let now = Date()
        
        // 1. Check for Existing OPEN Position
        if let existingIndex = journalEntries.firstIndex(where: { $0.symbol == symbol && $0.status == .open }) {
            var entry = journalEntries[existingIndex]
            
            // SMART LOGIC:
            // If we have a BUY and new signal is SELL -> CLOSE IT
            // If we have a SELL (Short) and new signal is BUY -> CLOSE IT
            let isClosing = (entry.action == "BUY" && newAction == "SELL") ||
                            (entry.action == "SELL" && newAction == "BUY")
            
            if isClosing {
                // CLOSE THE TRADE
                entry.status = .closed
                entry.currentPrice = price
                
                // Calculate Final PnL
                if entry.action == "BUY" {
                    // Long: (Exit - Entry) / Entry
                    entry.outcome = ((price - entry.entryPrice) / entry.entryPrice) * 100.0
                } else {
                    // Short: (Entry - Exit) / Entry
                    entry.outcome = ((entry.entryPrice - price) / entry.entryPrice) * 100.0
                }
                
                // Update Index
                DispatchQueue.main.async {
                    self.journalEntries[existingIndex] = entry
                    self.saveIndex()
                }
                print("✅ Argus Journal: Closed Trade for \(symbol). PnL: \(String(format: "%.2f", entry.outcome ?? 0))%")
                return // Done, don't open a new one yet (Wait for next signal)
            } else {
                // Same direction? (Buy on Buy)
                // For now, ignore duplicates to avoid spamming the journal.
                print("ℹ️ Argus Journal: Skipping duplicate \(newAction) signal for \(symbol).")
                return
            }
        }
        
        // 2. If No Open Position -> OPEN NEW TRADE
        // Only if confidence is high (which is checked by caller, but good to be safe)
        
        let id = UUID()
        
        // Create Deep Snapshot (Context)
        let scores = ArgusScores(
            atlas: decision.atlasScore,
            orion: decision.orionScore,
            aether: decision.aetherScore,
                hermes: decision.hermesScore,
                athena: decision.athenaScore,
                demeter: decision.demeterScore
        )
        
        let snapshot = SignalSnapshot(
            id: id,
            timestamp: now,
            symbol: symbol,
            price: price,
            scores: scores,
            decision: decision,
            candles: [], // TODO: Pass candles from ViewModel
            explanation: "Score: \(Int(decision.finalScoreCore)) Grade: \(decision.letterGradeCore)"
        )
        
        // Save Snapshot
        do {
            let data = try JSONEncoder().encode(snapshot)
            let fileURL = journalDir.appendingPathComponent("\(id.uuidString).json")
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save snapshot: \(error)")
            return
        }
        
        // Create Index Entry
        let entry = JournalEntry(
            id: id,
            symbol: symbol,
            date: now,
            action: newAction,
            status: .open,
            entryPrice: price,
            currentPrice: price,
            outcome: 0.0
        )
        
        // Update Index
        DispatchQueue.main.async {
            self.journalEntries.insert(entry, at: 0)
            self.saveIndex()
        }
        print("📝 Argus Journal: Opened \(newAction) Trade for \(symbol)")
    }
    
    func deleteEntry(id: UUID) {
        DispatchQueue.main.async {
            // Remove from memory
            self.journalEntries.removeAll { $0.id == id }
            self.saveIndex()
            
            // Remove file
            guard let journalDir = self.journalDirectory else { return }
            let fileURL = journalDir.appendingPathComponent("\(id.uuidString).json")
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - Persistence (File System)
    
    private func createDirectoryIfNeeded() {
        guard let url = journalDirectory else { return }
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func loadIndex() {
        guard let journalDir = journalDirectory else { return }
        let indexURL = journalDir.appendingPathComponent(indexFileName)
        
        if fileManager.fileExists(atPath: indexURL.path),
           let data = try? Data(contentsOf: indexURL),
           let loaded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            DispatchQueue.main.async {
                self.journalEntries = loaded
            }
        }
    }
    
    private func saveIndex() {
        guard let journalDir = journalDirectory else { return }
        let indexURL = journalDir.appendingPathComponent(indexFileName)
        
        if let data = try? JSONEncoder().encode(journalEntries) {
            try? data.write(to: indexURL)
        }
    }
    
    // MARK: - Argus Chronos (Performance Engine)
    
    /// Updates the PnL of all OPEN signals based on current market prices.
    func updatePerformance(quotes: [String: Double]) {
        var updated = false
        
        for i in 0..<journalEntries.count {
            if journalEntries[i].status == .open {
                let symbol = journalEntries[i].symbol
                if let currentPrice = quotes[symbol] {
                    // Calculate PnL
                    let entry = journalEntries[i].entryPrice
                    let pnl = (currentPrice - entry) / entry
                    let pnlPercent = pnl * 100.0
                    
                    // Update
                    journalEntries[i].currentPrice = currentPrice
                    journalEntries[i].outcome = pnlPercent
                    updated = true
                    
                    // Auto-Close Logic (Optional for now)
                    // if pnlPercent < -10 { self.journalEntries[i].status = .closed }
                }
            }
        }
        
        if updated {
            saveIndex()
        }
    }
}
