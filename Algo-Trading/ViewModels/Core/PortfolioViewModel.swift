import Foundation
import Combine
import SwiftUI

/// FAZ 2: PortfolioViewModel
/// Portföy yönetimi, işlemler ve bakiye kontrolü yapan ViewModel.
/// TradingViewModel'den ayrıştırıldı.
@MainActor
final class PortfolioViewModel: ObservableObject {
    
    // MARK: - Portfolio State
    @Published var portfolio: [Trade] = [] {
        didSet {
            savePortfolio()
        }
    }
    
    @Published var transactionHistory: [Transaction] = [] {
        didSet {
            saveTransactions()
        }
    }
    
    // MARK: - Balance State
    @Published var balance: Double = 100000.0 { // USD
        didSet {
            saveBalance()
        }
    }
    
    @Published var bistBalance: Double = 1000000.0 { // TL
        didSet {
            saveBistBalance()
        }
    }
    
    @Published var usdTryRate: Double = 35.0
    
    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var lastAction: String = ""
    @Published var lastTradeTimes: [String: Date] = [:]
    
    // MARK: - Quotes Reference (Koordinatör üzerinden güncellenir)
    @Published var quotes: [String: Quote] = [:]
    
    // MARK: - UserDefaults Keys
    private let portfolioKey = "user_portfolio"
    private let transactionsKey = "user_transactions"
    private let balanceKey = "user_balance"
    private let bistBalanceKey = "user_bist_balance"
    
    // MARK: - Init
    init() {
        loadPortfolio()
        loadBalance()
        loadBistBalance()
        loadTransactions()
    }
    
    // MARK: - Quote Updates (AppStateCoordinator'dan çağrılır)
    func handleQuoteUpdates(_ storeQuotes: [String: DataValue<Quote>]) {
        // Sadece açık pozisyonlar için quote'ları güncelle
        let openSymbols = Set(portfolio.filter { $0.isOpen }.map { $0.symbol })
        
        for symbol in openSymbols {
            if let dataValue = storeQuotes[symbol], let quote = dataValue.value {
                quotes[symbol] = quote
                
                // Stop Loss / Take Profit kontrolü
                for trade in portfolio.filter({ $0.symbol == symbol && $0.isOpen }) {
                    checkStopLoss(for: trade, currentPrice: quote.currentPrice)
                    checkTakeProfit(for: trade, currentPrice: quote.currentPrice)
                }
            }
        }
    }
    
    // MARK: - Trading Logic
    
    func buy(symbol: String, quantity: Double, price: Double, source: TradeSource = .user, stopLoss: Double? = nil, takeProfit: Double? = nil, rationale: String? = nil) {
        guard quantity > 0, price > 0 else {
            lastAction = "Hata: Geçersiz miktar veya fiyat"
            return
        }
        
        let cost = quantity * price
        let commission = FeeModel.shared.calculate(amount: cost)
        let totalCost = cost + commission
        
        // BIST kontrolü
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        let availableBalance = isBist ? bistBalance : balance
        
        guard availableBalance >= totalCost else {
            lastAction = "Bakiye Yetersiz! (Gereken: \(isBist ? "₺" : "$")\(Int(totalCost)), Mevcut: \(isBist ? "₺" : "$")\(Int(availableBalance)))"
            return
        }
        
        // Bakiye düş
        if isBist {
            bistBalance -= totalCost
        } else {
            balance -= totalCost
        }
        
        // Yeni işlem oluştur
        let newTrade = Trade(
            id: UUID(),
            symbol: symbol,
            entryPrice: price,
            quantity: quantity,
            entryDate: Date(),
            isOpen: true,
            source: source,
            engine: nil,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            rationale: rationale ?? "MANUAL_TRADE"
        )
        
        portfolio.append(newTrade)
        lastTradeTimes[symbol] = Date()
        
        // Transaction kaydı
        let transaction = Transaction(
            id: UUID(),
            type: .buy,
            symbol: symbol,
            amount: cost,
            price: price,
            date: Date(),
            fee: commission,
            pnl: nil,
            pnlPercent: nil
        )
        transactionHistory.append(transaction)
        
        lastAction = "Alındı: \(String(format: "%.2f", quantity))x \(symbol) @ \(isBist ? "₺" : "$")\(String(format: "%.2f", price))"
    }
    
    func sell(symbol: String, quantity: Double, price: Double, source: TradeSource = .user, reason: String? = nil) {
        guard quantity > 0, price > 0 else {
            lastAction = "Hata: Geçersiz miktar veya fiyat"
            return
        }
        
        // Açık pozisyonları bul
        let openTrades = portfolio.filter { $0.symbol == symbol && $0.isOpen }
        let totalOwned = openTrades.reduce(0.0) { $0 + $1.quantity }
        
        guard totalOwned >= quantity else {
            lastAction = "Hata: Yetersiz Pozisyon (\(symbol))"
            return
        }
        
        // FIFO: İlk gireni ilk sat
        var remainingToSell = quantity
        
        for i in portfolio.indices where portfolio[i].symbol == symbol && portfolio[i].isOpen && remainingToSell > 0 {
            let trade = portfolio[i]
            let sellQty = min(trade.quantity, remainingToSell)
            
            // PnL hesapla
            let pnl = (price - trade.entryPrice) * sellQty
            let pnlPct = ((price - trade.entryPrice) / trade.entryPrice) * 100
            
            // Komisyon
            let revenue = sellQty * price
            let commission = FeeModel.shared.calculate(amount: revenue)
            
            // BIST kontrolü
            let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
            if isBist {
                bistBalance += (revenue - commission)
            } else {
                balance += (revenue - commission)
            }
            
            // Pozisyonu güncelle
            if sellQty >= trade.quantity {
                portfolio[i].isOpen = false
                portfolio[i].exitDate = Date()
                portfolio[i].exitPrice = price
            } else {
                portfolio[i].quantity -= sellQty
            }
            
            // Transaction kaydı
            let transaction = Transaction(
                id: UUID(),
                type: .sell,
                symbol: symbol,
                amount: revenue,
                price: price,
                date: Date(),
                fee: commission,
                pnl: pnl,
                pnlPercent: pnlPct
            )
            transactionHistory.append(transaction)
            
            remainingToSell -= sellQty
        }
        
        lastTradeTimes[symbol] = Date()
        lastAction = "Satıldı: \(String(format: "%.2f", quantity))x \(symbol) @ $\(String(format: "%.2f", price))"
    }
    
    // MARK: - Stop Loss / Take Profit
    
    private func checkStopLoss(for trade: Trade, currentPrice: Double) {
        guard let stopLoss = trade.stopLoss, currentPrice <= stopLoss else { return }
        
        // Stop Loss tetiklendi
        sell(symbol: trade.symbol, quantity: trade.quantity, price: currentPrice, source: .autoPilot, reason: "STOP_LOSS")
    }
    
    private func checkTakeProfit(for trade: Trade, currentPrice: Double) {
        guard let takeProfit = trade.takeProfit, currentPrice >= takeProfit else { return }
        
        // Take Profit tetiklendi
        sell(symbol: trade.symbol, quantity: trade.quantity, price: currentPrice, source: .autoPilot, reason: "TAKE_PROFIT")
    }
    
    // MARK: - Computed Properties
    
    var openPositions: [Trade] {
        portfolio.filter { $0.isOpen }
    }
    
    var closedPositions: [Trade] {
        portfolio.filter { !$0.isOpen }
    }
    
    func getUnrealizedPnL() -> Double {
        openPositions.reduce(0.0) { total, trade in
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return total + ((currentPrice - trade.entryPrice) * trade.quantity)
        }
    }
    
    func getRealizedPnL() -> Double {
        transactionHistory
            .filter { $0.type == .sell }
            .compactMap { $0.pnl }
            .reduce(0.0, +)
    }
    
    // MARK: - Persistence
    
    private func savePortfolio() {
        if let data = try? JSONEncoder().encode(portfolio) {
            UserDefaults.standard.set(data, forKey: portfolioKey)
        }
    }
    
    private func loadPortfolio() {
        if let data = UserDefaults.standard.data(forKey: portfolioKey),
           let decoded = try? JSONDecoder().decode([Trade].self, from: data) {
            portfolio = decoded
        }
    }
    
    private func saveTransactions() {
        if let data = try? JSONEncoder().encode(transactionHistory) {
            UserDefaults.standard.set(data, forKey: transactionsKey)
        }
    }
    
    private func loadTransactions() {
        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            transactionHistory = decoded
        }
    }
    
    private func saveBalance() {
        UserDefaults.standard.set(balance, forKey: balanceKey)
    }
    
    private func loadBalance() {
        if UserDefaults.standard.object(forKey: balanceKey) != nil {
            balance = UserDefaults.standard.double(forKey: balanceKey)
        }
    }
    
    private func saveBistBalance() {
        UserDefaults.standard.set(bistBalance, forKey: bistBalanceKey)
    }
    
    private func loadBistBalance() {
        if UserDefaults.standard.object(forKey: bistBalanceKey) != nil {
            bistBalance = UserDefaults.standard.double(forKey: bistBalanceKey)
        }
    }
}
