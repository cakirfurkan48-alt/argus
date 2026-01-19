import Foundation
import SwiftUI
import Combine

// MARK: - Persistence & Storage
extension TradingViewModel {

    // MARK: - Watchlist Management
    func loadWatchlist() {
        // Managed by WatchlistStore
        // Binding setup in setupViewModelLinking() handles sync
    }
    
    func saveWatchlist() {
        // Managed by WatchlistStore
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

