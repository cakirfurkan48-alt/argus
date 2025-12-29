import Foundation
import Combine

// MARK: - Unified Fundamentals Store
// TEK KAYNAK PRENSİBİ: Tüm fundamental veriler burada.
// FundamentalsCache, FundamentalScoreStore, FundamentalsStore → BU TEK STORE

@MainActor
final class UnifiedFundamentalsStore: ObservableObject {
    static let shared = UnifiedFundamentalsStore()
    
    // MARK: - Data
    
    /// Ham API verisi (Revenue, NetIncome, vs.)
    @Published private(set) var rawData: [String: FinancialsData] = [:]
    
    /// Hesaplanmış skorlar (FundamentalScoreEngine çıktısı)
    @Published private(set) var scores: [String: FundamentalScoreResult] = [:]
    
    /// Son güncelleme zamanları
    private var lastUpdated: [String: Date] = [:]
    
    // MARK: - Config
    
    private let maxAgeSeconds: TimeInterval = 15 * 24 * 3600 // 15 gün
    private let fileName = "UnifiedFundamentals.json"
    
    // MARK: - Init
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Ham veri al (FinancialsData)
    func getRawData(for symbol: String) -> FinancialsData? {
        guard let data = rawData[symbol] else { return nil }
        guard !isStale(symbol: symbol) else { return nil }
        return data
    }
    
    /// Skor al (FundamentalScoreResult)
    func getScore(for symbol: String) -> FundamentalScoreResult? {
        guard let score = scores[symbol] else { return nil }
        guard !isStale(symbol: symbol) else { return nil }
        return score
    }
    
    /// Veri var mı ve geçerli mi?
    func hasValidData(for symbol: String) -> Bool {
        return getRawData(for: symbol) != nil && getScore(for: symbol) != nil
    }
    
    /// Ham veri kaydet
    func setRawData(symbol: String, data: FinancialsData) {
        rawData[symbol] = data
        lastUpdated[symbol] = Date()
        saveToDisk()
        print("✅ UnifiedStore: Raw data saved for \(symbol)")
    }
    
    /// Skor kaydet
    func setScore(_ score: FundamentalScoreResult) {
        scores[score.symbol] = score
        lastUpdated[score.symbol] = Date()
        saveToDisk()
        print("✅ UnifiedStore: Score saved for \(score.symbol) (Total: \(Int(score.totalScore)))")
    }
    
    /// Hem veri hem skor kaydet (convenience)
    func save(symbol: String, data: FinancialsData, score: FundamentalScoreResult) {
        rawData[symbol] = data
        scores[symbol] = score
        lastUpdated[symbol] = Date()
        saveToDisk()
        print("✅ UnifiedStore: Full save for \(symbol)")
    }
    
    /// Belirli sembolü temizle
    func invalidate(symbol: String) {
        rawData.removeValue(forKey: symbol)
        scores.removeValue(forKey: symbol)
        lastUpdated.removeValue(forKey: symbol)
        saveToDisk()
    }
    
    /// Tüm cache'i temizle
    func clearAll() {
        rawData.removeAll()
        scores.removeAll()
        lastUpdated.removeAll()
        saveToDisk()
    }
    
    // MARK: - Staleness Check
    
    private func isStale(symbol: String) -> Bool {
        guard let updated = lastUpdated[symbol] else { return true }
        return Date().timeIntervalSince(updated) > maxAgeSeconds
    }
    
    // MARK: - Persistence
    
    private struct StorageModel: Codable {
        let rawData: [String: FinancialsData]
        let scores: [String: FundamentalScoreResult]
        let lastUpdated: [String: Date]
    }
    
    private func getFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
    
    private func saveToDisk() {
        let model = StorageModel(rawData: rawData, scores: scores, lastUpdated: lastUpdated)
        do {
            let data = try JSONEncoder().encode(model)
            try data.write(to: getFileURL())
        } catch {
            print("❌ UnifiedStore: Save failed: \(error)")
        }
    }
    
    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: getFileURL())
            let model = try JSONDecoder().decode(StorageModel.self, from: data)
            self.rawData = model.rawData
            self.scores = model.scores
            self.lastUpdated = model.lastUpdated
            print("✅ UnifiedStore: Loaded \(scores.count) symbols from disk")
        } catch {
            print("⚠️ UnifiedStore: No existing data or decode error: \(error)")
        }
    }
    
    // MARK: - Migration (One-time)
    
    /// Eski store'lardan veri taşı
    func migrateFromLegacyStores() {
        // FundamentalScoreStore'dan
        let legacyScores = FundamentalScoreStore.shared
        
        // Reflection ile cache'e erişemiyoruz, o yüzden getScore'u kullanmalıyız
        // Ama hangi semboller var bilmiyoruz... 
        // Bu migration runtime'da yapılmalı - her veri erişiminde kontrol et
        
        print("⚠️ UnifiedStore: Migration deferred to runtime")
    }
}
