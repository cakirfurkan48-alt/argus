import Foundation
import Combine
import SwiftUI

// MARK: - BIST Trading View Model
// Sorumluluk: BIST portföyünü, TL bakiyesini ve işlemlerini yönetmek.
// Global TradingViewModel'den tamamen bağımsızdır.

@MainActor
class BistTradingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var watchlist: [String] = []  // Örn: ["THYAO.IS", "ASELS.IS"]
    @Published var portfolio: [BistTrade] = []
    @Published var transactions: [BistTransaction] = []
    @Published var balanceTRY: Double = 1_000_000.0 // Başlangıç: 1.000.000 TL
    
    // UI State
    @Published var quotes: [String: BistTicker] = [:]
    @Published var analysisResults: [String: OrionBistResult] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Services
    private let dataService = BistDataService.shared
    
    // MARK: - Initialization
    init() {
        loadData()
    }
    
    // MARK: - Data Loading
    func loadData() {
        // 1. Bakiye
        let savedBalance = UserDefaults.standard.double(forKey: "bist_balance_v1")
        if savedBalance > 0 {
            self.balanceTRY = savedBalance
        } else {
            self.balanceTRY = 1_000_000.0 // Default
            saveBalance()
        }
        
        // 2. Watchlist
        if let data = UserDefaults.standard.data(forKey: "bist_watchlist_v1"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.watchlist = decoded
        } else {
            // Default BIST 30'dan seçmeler
            self.watchlist = ["THYAO.IS", "ASELS.IS", "KCHOL.IS", "AKBNK.IS", "EREGL.IS", "BIMAS.IS", "TUPRS.IS", "SISE.IS"]
            saveWatchlist()
        }
        
        // 3. Portföy
        if let data = UserDefaults.standard.data(forKey: "bist_portfolio_v1"),
           let decoded = try? JSONDecoder().decode([BistTrade].self, from: data) {
            self.portfolio = decoded
        }
        
        // 4. Geçmiş
        if let data = UserDefaults.standard.data(forKey: "bist_transactions_v1"),
           let decoded = try? JSONDecoder().decode([BistTransaction].self, from: data) {
            self.transactions = decoded
        }
        
        // Verileri güncelle
        Task { await refreshQuotes() }
    }
    
    // MARK: - Market Actions
    func refreshQuotes() async {
        self.isLoading = true
        var newQuotes: [String: BistTicker] = [:]
        
        // Watchlist + Portföydeki hisseleri güncelle
        let allSymbols = Set(watchlist + portfolio.map { $0.symbol })
        
        for symbol in allSymbols {
            do {
                let ticker = try await dataService.fetchQuote(symbol: symbol)
                newQuotes[symbol] = ticker
            } catch {
                print("❌ BIST Quote Error (\(symbol)): \(error.localizedDescription)")
            }
        }
        
        self.quotes = newQuotes
        self.isLoading = false
    }
    
    // MARK: - Analysis (Orion BIST)
    func runOrionAnalysis(symbol: String) async {
        guard analysisResults[symbol] == nil else { return } // Zaten varsa tekrar yapma (Cache-like)
        
        do {
            // Analiz için geçmiş veriye ihtiyaç var (En az 60 mum)
            // Yahoo'dan 15dk'lık periyotta 5 günlük veri çekelim (yeterli mum verir)
            let candles = try await dataService.fetchHistory(symbol: symbol, interval: "15m", range: "10d")
            
            let result = OrionBistEngine.shared.analyze(candles: candles)
            
            // @MainActor olduğu için direkt set edebiliriz
            analysisResults[symbol] = result
        } catch {
            print("Analiz hatası (\(symbol)): \(error.localizedDescription)")
        }
    }
    func buy(symbol: String, quantity: Double) {
        guard let quote = quotes[symbol] else { return }
        let totalCost = quantity * quote.price
        
        if totalCost > balanceTRY {
            self.errorMessage = "Yetersiz Bakiye (Gereken: \(Int(totalCost)) TL)"
            return
        }
        
        // Bakiyeden düş
        balanceTRY -= totalCost
        
        // Portföye ekle
        let newTrade = BistTrade(
            id: UUID(),
            symbol: symbol,
            quantity: quantity,
            entryPrice: quote.price,
            entryDate: Date(),
            isOpen: true
        )
        portfolio.append(newTrade)
        
        // Log Transaction
        logTransaction(type: .buy, symbol: symbol, prices: quote.price, quantity: quantity, total: totalCost)
        
        // Kaydet
        saveBalance()
        savePortfolio()
    }
    
    func sell(tradeId: UUID, price: Double) {
        guard let index = portfolio.firstIndex(where: { $0.id == tradeId }) else { return }
        let trade = portfolio[index]
        
        let revenue = trade.quantity * price
        
        // Bakiyeye ekle
        balanceTRY += revenue
        
        // Portföyden çıkar (veya kapat)
        // Basitlik için listeden tamamen siliyoruz (FIFO değil, ID bazlı)
        portfolio.remove(at: index)
        
        // Log
        let pnl = revenue - (trade.quantity * trade.entryPrice)
        logTransaction(type: .sell, symbol: trade.symbol, prices: price, quantity: trade.quantity, total: revenue, pnl: pnl)
        
        // Kaydet
        saveBalance()
        savePortfolio()
    }
    
    private func logTransaction(type: BistTransactionType, symbol: String, prices: Double, quantity: Double, total: Double, pnl: Double? = nil) {
        let trx = BistTransaction(
            id: UUID(),
            type: type,
            symbol: symbol,
            quantity: quantity,
            price: prices,
            totalAmount: total,
            pnl: pnl,
            date: Date()
        )
        transactions.insert(trx, at: 0) // En yeni en üstte
        saveTransactions()
    }
    
    // MARK: - Auto Pilot (Argus BIST)
    @Published var isAutoPilotEnabled: Bool = false {
        didSet {
            // Persist state if needed or trigger check
            if isAutoPilotEnabled {
                print("Argus BIST Yöneticisi: AKTİF 🟢")
                Task { await runAutoPilotCycle() }
            } else {
                print("Argus BIST Yöneticisi: PASİF 🔴")
            }
        }
    }
    
    private func runAutoPilotCycle() async {
        while isAutoPilotEnabled {
            print("🚀 Argus BIST: Piyasa Taranıyor...")
            await refreshQuotes() // Fiyatları güncelle
            
            for symbol in watchlist {
                if !isAutoPilotEnabled { break }
                
                await runOrionAnalysis(symbol: symbol) // Analiz et
                
                if let result = analysisResults[symbol] {
                    let currentPosition = portfolio.first(where: { $0.symbol == symbol && $0.isOpen })
                    
                    // ALIM MANTIĞI (GÜÇLÜ AL ve Pozisyon Yoksa)
                    if result.signal == .buy && currentPosition == nil {
                        // Bakiye kontrolü (%10 ile gir)
                        let investmentAmount = balanceTRY * 0.10
                        if investmentAmount > 1000, let price = quotes[symbol]?.price {
                            let qty = floor(investmentAmount / price)
                            if qty > 0 {
                                buy(symbol: symbol, quantity: qty)
                                print("✅ OTO-ALIM: \(symbol) - \(qty) adet")
                            }
                        }
                    }
                    
                    // SATIM MANTIĞI (SAT Sinyali ve Pozisyon Varsa)
                    else if result.signal == .sell, let position = currentPosition, let price = quotes[symbol]?.price {
                        sell(tradeId: position.id, price: price)
                        print("❌ OTO-SATIM: \(symbol)")
                    }
                }
            }
            
            // 60 saniye bekle
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        }
    }
    func saveBalance() {
        UserDefaults.standard.set(balanceTRY, forKey: "bist_balance_v1")
    }
    
    func saveWatchlist() {
        if let encoded = try? JSONEncoder().encode(watchlist) {
            UserDefaults.standard.set(encoded, forKey: "bist_watchlist_v1")
        }
    }
    
    func savePortfolio() {
        if let encoded = try? JSONEncoder().encode(portfolio) {
            UserDefaults.standard.set(encoded, forKey: "bist_portfolio_v1")
        }
    }
    
    func saveTransactions() {
        if let encoded = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(encoded, forKey: "bist_transactions_v1")
        }
    }
}

// MARK: - Helper Models (Sadece burada kullanıldığı için)
struct BistTrade: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let quantity: Double
    let entryPrice: Double
    let entryDate: Date
    let isOpen: Bool
    
    // Computed
    func currentValue(price: Double) -> Double { quantity * price }
    func pnl(currentPrice: Double) -> Double { (currentPrice - entryPrice) * quantity }
    func pnlPercent(currentPrice: Double) -> Double { ((currentPrice - entryPrice) / entryPrice) * 100 }
}

struct BistTransaction: Codable, Identifiable {
    let id: UUID
    let type: BistTransactionType
    let symbol: String
    let quantity: Double
    let price: Double
    let totalAmount: Double
    let pnl: Double?
    let date: Date
}

enum BistTransactionType: String, Codable {
    case buy = "AL"
    case sell = "SAT"
}
