import Foundation
import Combine

struct AlertItem: Identifiable {
    let id = UUID()
    let symbol: String
    let date: Date
    let message: String
    let type: AlertType
    let score: Double
    
    enum AlertType {
        case buy
        case sell
        case neutral
    }
}

class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var alerts: [AlertItem] = []
    @Published var isScanning = false
    
    private init() {}
    
    func scanWatchlist(symbols: [String]) async {
        await MainActor.run { self.isScanning = true; self.alerts = [] }
        
        for symbol in symbols {
            do {
                // 1. Veri Çek (Backtest için historical)
                // BacktestEngine 3.5 yıllık veri istiyor ama sinyal için son 1 yıl veya daha azı da yetebilir.
                // Ancak tutarlılık için aynısını kullanalım.
                let candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1D", limit: 1200)
                
                // 2. Analiz Et
                let results = await BacktestEngine.shared.runAllStrategies(candles: candles)
                
                // 3. Sinyal Kontrolü
                // Ortak Sinyal Mantığı
                var totalScore = 0.0
                var buyWeight = 0.0
                var sellWeight = 0.0
                
                for result in results {
                    totalScore += result.score
                    if result.currentAction == SignalAction.buy {
                        buyWeight += result.score
                    } else if result.currentAction == SignalAction.sell {
                        sellWeight += result.score
                    }
                }
                
                if totalScore > 0 {
                    let buyStrength = (buyWeight / totalScore) * 100
                    let sellStrength = (sellWeight / totalScore) * 100
                    
                    if buyStrength > sellStrength && buyStrength > 60 { // %60 üzeri güven
                        let alert = AlertItem(symbol: symbol, date: Date(), message: "Güçlü AL Sinyali (Güven: %\(Int(buyStrength)))", type: .buy, score: buyStrength)
                        await MainActor.run { self.alerts.append(alert) }
                    } else if sellStrength > buyStrength && sellStrength > 60 {
                        let alert = AlertItem(symbol: symbol, date: Date(), message: "Güçlü SAT Sinyali (Güven: %\(Int(sellStrength)))", type: .sell, score: sellStrength)
                        await MainActor.run { self.alerts.append(alert) }
                    }
                }
                
            } catch {
                print("Alert scan error for \(symbol): \(error)")
            }
        }
        
        await MainActor.run {
            self.isScanning = false
            self.saveToWidget()
        }
    }
    
    private func saveToWidget() {
        // Widget için verileri hazırla (Basitleştirilmiş JSON)
        let widgetData = alerts.prefix(3).map { alert in
            [
                "symbol": alert.symbol,
                "score": alert.score,
                "type": alert.type == .buy ? "buy" : "sell",
                "message": alert.message
            ] as [String : Any]
        }
        
        if let userDefaults = UserDefaults(suiteName: "group.com.argus.Algo-Trading") {
            userDefaults.set(widgetData, forKey: "widgetSignals")
            // Widget'ı yenile
            // WidgetCenter.shared.reloadAllTimelines() // WidgetKit import etmek gerekir, burası Service katmanı olduğu için UI kodunu buraya karıştırmayalım veya import ekleyelim.
            // Şimdilik sadece kaydedelim.
        }
    }
}
