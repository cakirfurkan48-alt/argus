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
            // 2025 Analyst Picks (Added dynamically)
            "TSM", "MELI", "UBER", "ASML", "SHOP"
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
        
        // DYNAMIC INJECTION: Ensure 2025 Analyst Picks are present (One-time check logic ideally, but simpler to just append missing)
        let newPicks = ["TSM", "MELI", "UBER", "ASML", "SHOP"]
        var addedCount = 0
        for pick in newPicks {
            if !self.watchlist.contains(pick) {
                self.watchlist.append(pick)
                addedCount += 1
            }
        }
        if addedCount > 0 {
            print("✨ Added \(addedCount) new analyst picks to watchlist.")
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
    func loadTransactions() {
        if let data = UserDefaults.standard.data(forKey: "transactions_v2"),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            self.transactionHistory = decoded
        } else if let data = UserDefaults.standard.data(forKey: "transactions"),
                  let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            // Migration
            self.transactionHistory = decoded
            saveTransactions()
        }
    }
    
    func saveTransactions() {
        if let encoded = try? JSONEncoder().encode(transactionHistory) {
            UserDefaults.standard.set(encoded, forKey: "transactions_v2")
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
    
    // MARK: - Reset (Debug)
    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: "watchlist_v2")
        UserDefaults.standard.removeObject(forKey: "portfolio_v2")
        UserDefaults.standard.removeObject(forKey: "transactions_v2")
        UserDefaults.standard.removeObject(forKey: "user_balance_v2")
        
        // Reset In-Memory
        self.watchlist = ["AAPL", "NVDA", "TSLA", "MSFT", "GOOGL", "AMD", "PLTR", "COIN"]
        self.portfolio = []
        self.transactionHistory = []
        self.balance = 100_000.0
        
        saveWatchlist()
        savePortfolio()
        saveTransactions()
        saveBalance()
    }
}
