import Foundation

// MARK: - Forward Test Processor
/// Karakutu verilerini işleyip öğrenme sistemine besleyen motor
actor ForwardTestProcessor {
    static let shared = ForwardTestProcessor()
    
    private let ledger = ForwardTestLedger.shared
    private let chiron = ChironDataLakeService.shared
    
    // Doğrulama süreleri
    private let prometheusDaysToMature = 5  // Prometheus 5 gün bekler
    private let argusDaysToMature = 7       // Argus kararları 7 gün bekler
    
    // MARK: - Public API
    
    /// Olgunlaşmış tüm testleri işler ve sonuçları döner
    func processMaturedTests() async -> [ForwardTestResult] {
        var results: [ForwardTestResult] = []
        
        // 1. Prometheus tahminlerini işle
        let prometheusResults = await processPrometheusForecasts()
        results.append(contentsOf: prometheusResults)
        
        // 2. Argus kararlarını işle
        let argusResults = await processArgusDecisions()
        results.append(contentsOf: argusResults)
        
        // 3. Sonuçları Chiron'a kaydet
        await feedResultsToChiron(results)
        
        // 4. İşlenen verileri temizle
        // (Şimdilik temizleme yapmıyoruz, sonra eklenecek)
        
        return results
    }
    
    /// Bekleyen testleri listeler (UI için)
    func getPendingTests() async -> [PendingForwardTest] {
        var pending: [PendingForwardTest] = []
        
        // Prometheus bekleyenler
        let forecasts = await ledger.getUnprocessedForecasts()
        for f in forecasts {
            let daysSince = Calendar.current.dateComponents([.day], from: f.eventDate, to: Date()).day ?? 0
            let daysRemaining = prometheusDaysToMature - daysSince
            
            pending.append(PendingForwardTest(
                id: f.eventId,
                symbol: f.symbol,
                testType: .prometheusforecast,
                eventDate: f.eventDate,
                originalPrice: f.currentPrice,
                predictedPrice: f.predictedPrice,
                predictedAction: nil,
                daysUntilMature: max(0, daysRemaining)
            ))
        }
        
        // Argus bekleyenler
        let decisions = await ledger.getUnprocessedDecisions()
        for d in decisions {
            let daysSince = Calendar.current.dateComponents([.day], from: d.eventDate, to: Date()).day ?? 0
            let daysRemaining = argusDaysToMature - daysSince
            
            pending.append(PendingForwardTest(
                id: d.eventId,
                symbol: d.symbol,
                testType: .argusDecision,
                eventDate: d.eventDate,
                originalPrice: d.currentPrice,
                predictedPrice: nil,
                predictedAction: d.action,
                daysUntilMature: max(0, daysRemaining)
            ))
        }
        
        return pending.sorted { $0.eventDate > $1.eventDate }
    }
    
    /// İstatistikleri hesaplar
    func calculateStats() async -> ForwardTestStats {
        let results = await loadProcessedResults()
        
        guard !results.isEmpty else {
            return .empty
        }
        
        let correct = results.filter { $0.wasCorrect }.count
        let hitRate = Double(correct) / Double(results.count)
        let avgAccuracy = results.map { $0.accuracy }.reduce(0, +) / Double(results.count)
        
        // Tip bazlı
        let prometheus = results.filter { $0.testType == .prometheusforecast }
        let argus = results.filter { $0.testType == .argusDecision }
        
        let prometheusHit = prometheus.isEmpty ? 0 : Double(prometheus.filter { $0.wasCorrect }.count) / Double(prometheus.count)
        let argusHit = argus.isEmpty ? 0 : Double(argus.filter { $0.wasCorrect }.count) / Double(argus.count)
        
        return ForwardTestStats(
            totalTests: results.count,
            correctTests: correct,
            hitRate: hitRate,
            averageAccuracy: avgAccuracy,
            prometheusHitRate: prometheusHit,
            argusHitRate: argusHit,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Processing
    
    private func processPrometheusForecasts() async -> [ForwardTestResult] {
        let forecasts = await ledger.getUnprocessedForecasts()
        var results: [ForwardTestResult] = []
        
        for forecast in forecasts {
            let daysSince = Calendar.current.dateComponents([.day], from: forecast.eventDate, to: Date()).day ?? 0
            guard daysSince >= prometheusDaysToMature else { continue }
            
            // Gerçek fiyatı çek (güncel quote)
            guard let actualPrice = await fetchCurrentPrice(symbol: forecast.symbol) else { continue }
            
            let actualChange = ((actualPrice - forecast.currentPrice) / forecast.currentPrice) * 100
            let predictedChange = ((forecast.predictedPrice - forecast.currentPrice) / forecast.currentPrice) * 100
            
            // Doğruluk kriteri: Yön doğru mu?
            let wasCorrect = (predictedChange >= 0 && actualChange >= 0) || (predictedChange < 0 && actualChange < 0)
            
            // Accuracy: Tahmin ne kadar yakın? (0-100)
            let errorPercent = abs(actualChange - predictedChange)
            let accuracy = max(0, 100 - errorPercent * 10) // Her %1 hata için 10 puan düş
            
            let result = ForwardTestResult(
                id: UUID(),
                symbol: forecast.symbol,
                testType: .prometheusforecast,
                eventDate: forecast.eventDate,
                verificationDate: Date(),
                originalPrice: forecast.currentPrice,
                predictedPrice: forecast.predictedPrice,
                predictedAction: nil,
                actualPrice: actualPrice,
                actualChange: actualChange,
                wasCorrect: wasCorrect,
                accuracy: accuracy,
                moduleScores: nil,
                notes: "Tahmin: \(String(format: "%.1f", predictedChange))%, Gerçek: \(String(format: "%.1f", actualChange))%"
            )
            
            results.append(result)
            
            // Event'i işlenmiş olarak işaretle
            await ledger.markEventProcessed(eventId: forecast.eventId)
        }
        
        return results
    }
    
    private func processArgusDecisions() async -> [ForwardTestResult] {
        let decisions = await ledger.getUnprocessedDecisions()
        var results: [ForwardTestResult] = []
        
        for decision in decisions {
            let daysSince = Calendar.current.dateComponents([.day], from: decision.eventDate, to: Date()).day ?? 0
            guard daysSince >= argusDaysToMature else { continue }
            
            // Gerçek fiyatı çek
            guard let actualPrice = await fetchCurrentPrice(symbol: decision.symbol) else { continue }
            
            let actualChange = ((actualPrice - decision.currentPrice) / decision.currentPrice) * 100
            
            // Doğruluk kriteri
            let wasCorrect: Bool
            switch decision.action.uppercased() {
            case "BUY", "AGGRESSIVE_BUY", "ACCUMULATE":
                wasCorrect = actualChange > 0
            case "SELL", "LIQUIDATE", "TRIM":
                wasCorrect = actualChange < 0
            case "HOLD", "NEUTRAL":
                wasCorrect = abs(actualChange) < 5 // %5'ten az değişim
            default:
                wasCorrect = false
            }
            
            // Accuracy: Değişimin büyüklüğüne göre (doğruysa yüksek, yanlışsa düşük)
            let accuracy = wasCorrect ? min(100, 50 + abs(actualChange) * 5) : max(0, 50 - abs(actualChange) * 5)
            
            let result = ForwardTestResult(
                id: UUID(),
                symbol: decision.symbol,
                testType: .argusDecision,
                eventDate: decision.eventDate,
                verificationDate: Date(),
                originalPrice: decision.currentPrice,
                predictedPrice: nil,
                predictedAction: decision.action,
                actualPrice: actualPrice,
                actualChange: actualChange,
                wasCorrect: wasCorrect,
                accuracy: accuracy,
                moduleScores: decision.moduleScores,
                notes: "Karar: \(decision.action), Sonuç: \(String(format: "%.1f", actualChange))%"
            )
            
            results.append(result)
            await ledger.markEventProcessed(eventId: decision.eventId)
        }
        
        return results
    }
    
    // MARK: - Chiron Integration
    
    private func feedResultsToChiron(_ results: [ForwardTestResult]) async {
        for result in results {
            // Chiron learning event olarak kaydet
            let event = ChironLearningEvent(
                id: UUID(),
                date: result.verificationDate,
                eventType: .forwardTest,
                symbol: result.symbol,
                engine: nil,
                description: result.wasCorrect ? "Forward test basarili" : "Forward test basarisiz",
                reasoning: result.notes ?? "",
                confidence: result.accuracy / 100
            )
            
            await chiron.logLearningEvent(event)
        }
    }
    
    // MARK: - Helpers
    
    private func fetchCurrentPrice(symbol: String) async -> Double? {
        // MarketDataStore'dan güncel fiyatı al
        let result = await MarketDataStore.shared.ensureQuote(symbol: symbol)
        return result.value?.currentPrice
    }
    
    private func loadProcessedResults() async -> [ForwardTestResult] {
        // Disk'ten işlenmiş sonuçları yükle
        let path = getResultsFilePath()
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode([ForwardTestResult].self, from: data)
        } catch {
            return []
        }
    }
    
    private func saveResults(_ results: [ForwardTestResult]) async {
        var existing = await loadProcessedResults()
        existing.append(contentsOf: results)
        
        // Son 1000 sonucu tut
        if existing.count > 1000 {
            existing = Array(existing.suffix(1000))
        }
        
        let path = getResultsFilePath()
        do {
            let data = try JSONEncoder().encode(existing)
            try data.write(to: path)
        } catch {
            print("ForwardTestProcessor: Sonuc kaydetme hatasi - \(error)")
        }
    }
    
    private func getResultsFilePath() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ForwardTestResults.json")
    }
}

// MARK: - Ledger Helper Structs
struct ForecastEventData {
    let eventId: String
    let symbol: String
    let eventDate: Date
    let currentPrice: Double
    let predictedPrice: Double
}

struct DecisionEventData {
    let eventId: String
    let symbol: String
    let eventDate: Date
    let currentPrice: Double
    let action: String
    let moduleScores: [String: Double]?
}
