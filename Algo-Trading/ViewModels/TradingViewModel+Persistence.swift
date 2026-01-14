import Foundation
import SwiftUI
import Combine

// MARK: - Persistence & Storage
extension TradingViewModel {

    // MARK: - Watchlist Management
    func loadWatchlist() {
        // User requested manual reset/rebuild
        let comprehensiveUniverse: [String] = [
            // Technology (20)
            "AAPL", "MSFT", "NVDA", "AVGO", "ORCL", "ADBE", "CRM", "AMD", "QCOM", "TXN",
            "IBM", "INTC", "NOW", "AMAT", "MU", "LRCX", "ADI", "KLAC", "PANW", "SNOW", "PLTR",
            // Communication (10)
            "GOOGL", "META", "NFLX", "DIS", "CMCSA", "TMUS", "VZ", "T", "CHTR", "WBD",
            // Financials (15)
            "JPM", "V", "MA", "BAC", "WFC", "MS", "GS", "BLK", "C", "AXP", "SPGI", "CB", "MMC", "PGR", "SCHW", "COIN",
            // Healthcare (15)
            "LLY", "UNH", "JNJ", "MRK", "ABBV", "TMO", "PFE", "AMGN", "ISRG", "ABT", "DHR", "BMY", "CVS", "ELV", "GILD",
            // Consumer Discretionary (12)
            "AMZN", "TSLA", "HD", "MCD", "NKE", "SBUX", "BKNG", "TJX", "LOW", "LVS", "MAR", "HLT",
            // Consumer Staples (10)
            "WMT", "PG", "COST", "KO", "PEP", "PM", "MO", "CL", "TGT", "EL",
            // Energy (8)
            "XOM", "CVX", "COP", "SLB", "EOG", "OXY", "MPC", "PSX",
            // Industrials (10)
            "CAT", "GE", "UNP", "HON", "UPS", "LMT", "RTX", "BA", "DE", "MMM",
            // Materials (4)
            "LIN", "SHW", "FCX", "NEM",
            // Real Estate (4)
            "PLD", "AMT", "EQIX", "O",
            // Utilities (3)
            "NEE", "SO", "DUK",
            // Crypto (2)
            "BTC-USD", "ETH-USD",
            // 2025 Analyst Picks
            "TSM", "MELI", "UBER", "ASML", "SHOP",
            
            // BIST 50 - Türkiye Borsası (Kaliteli Hisseler)
            "THYAO.IS", "ASELS.IS", "KCHOL.IS", "AKBNK.IS", "GARAN.IS",
            "SAHOL.IS", "TUPRS.IS", "EREGL.IS", "BIMAS.IS", "SISE.IS",
            "PETKM.IS", "SASA.IS", "HEKTS.IS", "FROTO.IS", "TOASO.IS",
            "ENKAI.IS", "ISCTR.IS", "YKBNK.IS", "VAKBN.IS", "HALKB.IS",
            "PGSUS.IS", "TAVHL.IS", "TCELL.IS", "TTKOM.IS", "KOZAL.IS",
            "KOZAA.IS", "TKFEN.IS", "MGROS.IS", "SOKM.IS", "AEFES.IS",
            "ARCLK.IS", "ALARK.IS", "ASTOR.IS", "BRSAN.IS", "CIMSA.IS",
            "DOAS.IS", "EGEEN.IS", "EKGYO.IS", "ENJSA.IS", "GESAN.IS",
            "KONTR.IS", "ODAS.IS", "ULKER.IS", "VESTL.IS", "GUBRF.IS",
            "AKSEN.IS", "KORDS.IS", "LOGO.IS", "MAVI.IS", "OTKAR.IS"
        ].sorted()
        
        // Priority: Check v2
        if let data = UserDefaults.standard.data(forKey: "watchlist_v2"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.watchlist = decoded
        } else if let legacyData = UserDefaults.standard.data(forKey: "watchlist"),
                  let decoded = try? JSONDecoder().decode([String].self, from: legacyData) {
            // MIGRATION: Restore Legacy Data
            print("📦 Migration: Restored Watchlist from Legacy Storage")
            self.watchlist = decoded
            saveWatchlist()
        }
        
        // FAILSAFE: If user has fewer than 10 symbols, assume list is "broken" or "empty" and restore FULL universe.
        if self.watchlist.isEmpty || (self.watchlist.count < 5 && UserDefaults.standard.object(forKey: "watchlist_v2") == nil) {
            print("⚠️ Watchlist empty/new. Initializing Comprehensive Universe.")
            self.watchlist = comprehensiveUniverse
            saveWatchlist()
        }
        
        // DYNAMIC INJECTION: Ensure BIST + 2025 Analyst Picks are present
        let requiredSymbols = [
            // 2025 Picks
            "TSM", "MELI", "UBER", "ASML", "SHOP",
            // BIST Core 50
            "THYAO.IS", "ASELS.IS", "KCHOL.IS", "AKBNK.IS", "GARAN.IS",
            "SAHOL.IS", "TUPRS.IS", "EREGL.IS", "BIMAS.IS", "SISE.IS",
            "PETKM.IS", "SASA.IS", "HEKTS.IS", "FROTO.IS", "TOASO.IS",
            "ENKAI.IS", "ISCTR.IS", "YKBNK.IS", "VAKBN.IS", "HALKB.IS",
            "PGSUS.IS", "TAVHL.IS", "TCELL.IS", "TTKOM.IS", "KOZAL.IS",
            "KOZAA.IS", "TKFEN.IS", "MGROS.IS", "SOKM.IS", "AEFES.IS",
            "ARCLK.IS", "ALARK.IS", "ASTOR.IS", "BRSAN.IS", "CIMSA.IS",
            "DOAS.IS", "EGEEN.IS", "EKGYO.IS", "ENJSA.IS", "GESAN.IS",
            "KONTR.IS", "ODAS.IS", "ULKER.IS", "VESTL.IS", "GUBRF.IS",
            "AKSEN.IS", "KORDS.IS", "LOGO.IS", "MAVI.IS", "OTKAR.IS"
        ]
        var addedCount = 0
        for symbol in requiredSymbols {
            if !self.watchlist.contains(symbol) {
                self.watchlist.append(symbol)
                addedCount += 1
            }
        }
        if addedCount > 0 {
            print("✨ Added \(addedCount) new symbols (incl. BIST 50) to watchlist.")
            saveWatchlist()
        }
    }
    
    func saveWatchlist() {
        if let encoded = try? JSONEncoder().encode(watchlist) {
            UserDefaults.standard.set(encoded, forKey: "watchlist_v2")
        }
    }
    
    func deleteFromWatchlist(at offsets: IndexSet) {
        watchlist.remove(atOffsets: offsets)
        saveWatchlist()
    }
    
    // MARK: - Portfolio Management
    func loadPortfolio() {
        if let data = UserDefaults.standard.data(forKey: "portfolio_v2"),
           let decoded = try? JSONDecoder().decode([Trade].self, from: data) {
            self.portfolio = decoded
        } else if let legacyData = UserDefaults.standard.data(forKey: "portfolio"),
                  let decoded = try? JSONDecoder().decode([Trade].self, from: legacyData) {
            // MIGRATION: Restore Legacy Portfolio
            print("📦 Migration: Restored Portfolio from Legacy Storage")
            self.portfolio = decoded
            savePortfolio()
        }
    }
    
    func savePortfolio() {
        if let encoded = try? JSONEncoder().encode(portfolio) {
            UserDefaults.standard.set(encoded, forKey: "portfolio_v2")
        }
    }
    
    // MARK: - Transaction History Management
    
    /// Transaction'lar için dosya URL'i (UserDefaults limiti 1MB, bu yeterli değil)
    private var transactionsFileURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("ArgusTerminal", isDirectory: true)
        
        // Dizin yoksa oluştur
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir.appendingPathComponent("transactions_v3.json")
    }
    
    func loadTransactions() {
        // V3: Dosya bazlı storage (öncelikli)
        if FileManager.default.fileExists(atPath: transactionsFileURL.path) {
            do {
                let data = try Data(contentsOf: transactionsFileURL)
                let decoded = try JSONDecoder().decode([Transaction].self, from: data)
                self.transactionHistory = decoded
                print("✅ Transactions loaded from file: \(decoded.count) işlem")
                return
            } catch {
                print("❌ Transaction dosya okuma hatası: \(error)")
            }
        }
        
        // V2 Migration: UserDefaults'tan dosyaya taşı
        if let data = UserDefaults.standard.data(forKey: "transactions_v2"),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            self.transactionHistory = decoded
            print("📦 Migration: \(decoded.count) transaction UserDefaults'tan dosyaya taşınıyor...")
            saveTransactions() // Dosyaya kaydet
            // Eski veriyi temizle (opsiyonel)
            // UserDefaults.standard.removeObject(forKey: "transactions_v2")
        } else if let data = UserDefaults.standard.data(forKey: "transactions"),
                  let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            // Legacy Migration
            self.transactionHistory = decoded
            saveTransactions()
        }
    }
    
    func saveTransactions() {
        // Rolling Window: Son 500 işlemi tut, eskilerini sil
        let maxTransactions = 500
        if transactionHistory.count > maxTransactions {
            let excessCount = transactionHistory.count - maxTransactions
            transactionHistory.removeFirst(excessCount)
            print("🧹 Eski işlemler temizlendi: \(excessCount) adet silindi, \(maxTransactions) kaldı")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(transactionHistory)
            try data.write(to: transactionsFileURL, options: .atomic)
            
            let sizeKB = Double(data.count) / 1024.0
            print("✅ Transactions saved: \(transactionHistory.count) işlem (\(String(format: "%.1f", sizeKB)) KB)")
        } catch {
            print("❌ Transaction kaydetme HATASI: \(error)")
            print("   Dosya: \(transactionsFileURL.path)")
            print("   İşlem sayısı: \(transactionHistory.count)")
        }
    }
    
    // MARK: - Balance Management
    func loadBalance() {
        // Check V2
        let savedV2 = UserDefaults.standard.double(forKey: "user_balance_v2")
        if savedV2 > 0 {
            self.balance = savedV2
        } else {
            // Check Legacy
            let savedLegacy = UserDefaults.standard.double(forKey: "user_balance")
            if savedLegacy > 0 {
                self.balance = savedLegacy
                saveBalance()
            } else {
                self.balance = 100_000.0 // Default Paper Money
            }
        }
    }
    
    func saveBalance() {
        UserDefaults.standard.set(balance, forKey: "user_balance_v2")
    }
    
    func saveBistBalance() {
        UserDefaults.standard.set(bistBalance, forKey: "bist_balance_v1")
    }
    
    func loadBistBalance() {
        if let saved = UserDefaults.standard.object(forKey: "bist_balance_v1") as? Double {
            self.bistBalance = saved
        } else {
            // İlk kez - 1M TL demo bakiyesi
            self.bistBalance = 1_000_000.0
        }
    }
    
    // MARK: - BIST Bakiye Düzeltme
    /// Bakiyeyi mevcut pozisyonların alış maliyetlerine göre yeniden hesaplar
    /// Formül: Nakit = Başlangıç (1M) - Σ(Adet × Alış Fiyatı)
    func recalculateBistBalance() {
        let startingBalance = 1_000_000.0
        
        // Açık BIST pozisyonlarının toplam alış maliyetini hesapla
        var totalCost: Double = 0.0
        for trade in portfolio where trade.isOpen {
            let isBist = trade.symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(trade.symbol)
            if isBist {
                totalCost += trade.entryPrice * trade.quantity
            }
        }
        
        // Eğer maliyet başlangıç bakiyesinden fazlaysa (imkansız durum)
        // En azından 0 olarak ayarla ve uyarı ver
        let correctedBalance = max(0, startingBalance - totalCost)
        
        let oldBalance = bistBalance
        bistBalance = correctedBalance
        saveBistBalance()
        
        print("🔧 BIST Bakiye Düzeltildi:")
        print("   Eski: ₺\(String(format: "%.2f", oldBalance))")
        print("   Yeni: ₺\(String(format: "%.2f", correctedBalance))")
        print("   Aktif Pozisyon Maliyeti: ₺\(String(format: "%.2f", totalCost))")
    }
    
    // MARK: - BIST Tam Reset (Portföy + Bakiye)
    // Moved to main TradingViewModel.swift for visibility


    
    // MARK: - Reset (Debug)
    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: "watchlist_v2")
        UserDefaults.standard.removeObject(forKey: "portfolio_v2")
        UserDefaults.standard.removeObject(forKey: "transactions_v2")
        UserDefaults.standard.removeObject(forKey: "user_balance_v2")
        UserDefaults.standard.removeObject(forKey: "bist_balance_v1")
        
        // Reset In-Memory
        self.watchlist = ["AAPL", "NVDA", "TSLA", "MSFT", "GOOGL", "AMD", "PLTR", "COIN"]
        self.portfolio = []
        self.transactionHistory = []
        self.balance = 100_000.0
        self.bistBalance = 1_000_000.0
        
        saveWatchlist()
        savePortfolio()
        saveTransactions()
        saveBalance()
        saveBistBalance()
        
        print("🗑️ All data reset (incl. BIST 1M TL)")
    }
}

