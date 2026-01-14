import Foundation
import Combine
import SwiftUI

/// PortfolioStore: Portföy ve bakiye yönetimi için ayrılmış store.
/// TradingViewModel'den ayrılarak performans optimizasyonu sağlar.
/// Sadece portfolio değiştiğinde ilgili view'lar yeniden render olur.
@MainActor
final class PortfolioStore: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PortfolioStore()
    
    // MARK: - Published Properties (Minimal)
    @Published private(set) var portfolio: [Trade] = []
    @Published private(set) var balance: Double = 100_000.0  // USD
    @Published private(set) var bistBalance: Double = 1_000_000.0  // TL
    @Published private(set) var transactionHistory: [Transaction] = []
    
    // MARK: - Persistence Keys
    private let portfolioKey = "argus_portfolio_v2"
    private let balanceKey = "argus_balance_v2"
    private let bistBalanceKey = "argus_bist_balance_v1"
    private let transactionsKey = "argus_transactions_v2"
    
    // MARK: - Init
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Computed Properties
    
    var openPositions: [Trade] {
        portfolio.filter { $0.isOpen }
    }
    
    var globalOpenPositions: [Trade] {
        openPositions.filter { !isBistSymbol($0.symbol) }
    }
    
    var bistOpenPositions: [Trade] {
        openPositions.filter { isBistSymbol($0.symbol) }
    }
    
    // MARK: - Balance Helpers
    
    func availableBalance(for symbol: String) -> Double {
        isBistSymbol(symbol) ? bistBalance : balance
    }
    
    // MARK: - Buy
    
    func buy(
        symbol: String,
        quantity: Double,
        price: Double,
        source: TradeSource = .user,
        engine: AutoPilotEngine? = nil,
        stopLoss: Double? = nil,
        takeProfit: Double? = nil,
        rationale: String? = nil,
        orionSnapshot: OrionComponentSnapshot? = nil  // NEW: Chiron öğrenme için
    ) -> Bool {
        guard quantity > 0, price > 0 else { return false }
        
        let cost = quantity * price
        let commission = FeeModel.shared.calculate(amount: cost)
        let totalCost = cost + commission
        
        let isBist = isBistSymbol(symbol)
        let available = isBist ? bistBalance : balance
        
        guard available >= totalCost else {
            print("❌ PortfolioStore: Yetersiz bakiye. Gerekli: \(totalCost), Mevcut: \(available)")
            return false
        }
        
        // Deduct balance
        if isBist {
            bistBalance -= totalCost
        } else {
            balance -= totalCost
        }
        
        // Create trade
        var trade = Trade(
            id: UUID(),
            symbol: symbol,
            entryPrice: price,
            quantity: quantity,
            entryDate: Date(),
            isOpen: true,
            source: source,
            engine: engine,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            rationale: rationale ?? (source == .autoPilot ? "AUTO_SIGNAL" : "MANUAL")
        )
        
        // NEW: Attach Orion Snapshot for Chiron Learning
        trade.entryOrionSnapshot = orionSnapshot
        
        portfolio.append(trade)
        
        // Log transaction
        var transaction = Transaction(
            id: UUID(),
            type: .buy,
            symbol: symbol,
            amount: cost,
            price: price,
            date: Date(),
            fee: commission
        )
        transaction.source = source.rawValue
        transaction.reasonCode = rationale
        transactionHistory.insert(transaction, at: 0)
        
        saveToDisk()
        
        print("✅ PortfolioStore: BUY \(symbol) x\(quantity) @ \(price)")
        return true
    }
    
    // MARK: - Sell
    
    func sell(tradeId: UUID, currentPrice: Double) -> Double? {
        guard let index = portfolio.firstIndex(where: { $0.id == tradeId && $0.isOpen }) else {
            print("❌ PortfolioStore: Trade bulunamadı: \(tradeId)")
            return nil
        }
        
        var trade = portfolio[index]
        let proceeds = trade.quantity * currentPrice
        let commission = FeeModel.shared.calculate(amount: proceeds)
        let netProceeds = proceeds - commission
        
        let pnl = (currentPrice - trade.entryPrice) * trade.quantity - commission
        
        // Add to balance
        let isBist = isBistSymbol(trade.symbol)
        if isBist {
            bistBalance += netProceeds
        } else {
            balance += netProceeds
        }
        
        // Close trade (profit is computed from exitPrice)
        trade.isOpen = false
        trade.exitPrice = currentPrice
        trade.exitDate = Date()
        portfolio[index] = trade
        
        // NEW: Create TradeLog for Chiron Learning
        let tradeLog = TradeLog(
            date: Date(),
            symbol: trade.symbol,
            entryPrice: trade.entryPrice,
            exitPrice: currentPrice,
            pnlPercent: trade.profitPercentage,
            pnlAbsolute: pnl,
            entryRegime: .neutral, // Placeholder - ideally from ChironRegimeEngine
            entryOrionScore: trade.entryOrionSnapshot?.orionTotal ?? 0,
            entryAtlasScore: 0, // Could be enhanced with more context
            entryAetherScore: 0,
            engine: trade.source == .autoPilot ? "AutoPilot" : "Manual",
            entryOrionSnapshot: trade.entryOrionSnapshot,
            exitOrionSnapshot: nil // Could add exit snapshot if needed
        )
        TradeLogStore.shared.append(tradeLog)
        
        // Log transaction
        var transaction = Transaction(
            id: UUID(),
            type: .sell,
            symbol: trade.symbol,
            amount: proceeds,
            price: currentPrice,
            date: Date(),
            fee: commission
        )
        transaction.source = trade.source.rawValue
        transaction.pnl = pnl
        transaction.pnlPercent = trade.entryPrice > 0 ? (pnl / (trade.entryPrice * trade.quantity)) * 100 : 0
        transactionHistory.insert(transaction, at: 0)
        
        saveToDisk()
        
        print("✅ PortfolioStore: SELL \(trade.symbol) @ \(currentPrice), PnL: \(pnl)")
        return pnl
    }
    
    // MARK: - Portfolio Value Calculations
    
    func getTotalPortfolioValue(quotes: [String: Quote]) -> Double {
        globalOpenPositions.reduce(0.0) { sum, trade in
            let price = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + (price * trade.quantity)
        }
    }
    
    func getBistPortfolioValue(quotes: [String: Quote]) -> Double {
        bistOpenPositions.reduce(0.0) { sum, trade in
            let price = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + (price * trade.quantity)
        }
    }
    
    func getEquity(quotes: [String: Quote]) -> Double {
        balance + getTotalPortfolioValue(quotes: quotes)
    }
    
    func getBistEquity(quotes: [String: Quote]) -> Double {
        bistBalance + getBistPortfolioValue(quotes: quotes)
    }
    
    func getUnrealizedPnL(quotes: [String: Quote]) -> Double {
        globalOpenPositions.reduce(0.0) { sum, trade in
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + ((currentPrice - trade.entryPrice) * trade.quantity)
        }
    }
    
    func getBistUnrealizedPnL(quotes: [String: Quote]) -> Double {
        bistOpenPositions.reduce(0.0) { sum, trade in
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + ((currentPrice - trade.entryPrice) * trade.quantity)
        }
    }
    
    func getRealizedPnL() -> Double {
        portfolio
            .filter { !$0.isOpen && !isBistSymbol($0.symbol) }
            .reduce(0.0) { $0 + $1.profit }
    }
    
    func getBistRealizedPnL() -> Double {
        portfolio
            .filter { !$0.isOpen && isBistSymbol($0.symbol) }
            .reduce(0.0) { $0 + $1.profit }
    }
    
    // MARK: - Reset
    
    func reset() {
        portfolio = []
        balance = 100_000.0
        bistBalance = 1_000_000.0
        transactionHistory = []
        saveToDisk()
        print("🔄 PortfolioStore: Reset to initial state")
    }
    
    // MARK: - Helpers
    
    private func isBistSymbol(_ symbol: String) -> Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        let encoder = JSONEncoder()
        
        if let portfolioData = try? encoder.encode(portfolio) {
            UserDefaults.standard.set(portfolioData, forKey: portfolioKey)
        }
        
        if let txData = try? encoder.encode(transactionHistory) {
            UserDefaults.standard.set(txData, forKey: transactionsKey)
        }
        
        UserDefaults.standard.set(balance, forKey: balanceKey)
        UserDefaults.standard.set(bistBalance, forKey: bistBalanceKey)
    }
    
    private func loadFromDisk() {
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: portfolioKey),
           let saved = try? decoder.decode([Trade].self, from: data) {
            portfolio = saved
        }
        
        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let saved = try? decoder.decode([Transaction].self, from: data) {
            transactionHistory = saved
        }
        
        if UserDefaults.standard.object(forKey: balanceKey) != nil {
            balance = UserDefaults.standard.double(forKey: balanceKey)
        }
        
        if UserDefaults.standard.object(forKey: bistBalanceKey) != nil {
            bistBalance = UserDefaults.standard.double(forKey: bistBalanceKey)
        }
        
        print("📂 PortfolioStore: Loaded \(portfolio.count) trades, Balance: $\(balance), BIST: ₺\(bistBalance)")
    }
}
