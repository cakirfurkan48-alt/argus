import Foundation
import Combine

// MARK: - Portfolio Manager
// TradingViewModel'dan extract edilmiş portfolio yönetim modülü

@MainActor
final class PortfolioManager: ObservableObject, PortfolioManaging {
    
    // MARK: - Singleton (Legacy Support - Geçiş döneminde)
    static let shared = PortfolioManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var portfolio: [Trade] = []
    
    @Published var balance: Double = 100000.0 {
        didSet { saveBalance() }
    }
    
    @Published var bistBalance: Double = 1000000.0 {
        didSet { saveBistBalance() }
    }
    
    @Published private(set) var transactionHistory: [Transaction] = []
    
    // MARK: - State
    
    var lastTradeTimes: [String: Date] = [:]
    
    // MARK: - Dependencies
    
    private let feeModel = FeeModel.shared
    private let config: TradingConfig
    
    // MARK: - Combine
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        self.config = TradingConfig.default
        loadSavedData()
    }
    
    /// Test initialization with custom config
    init(config: TradingConfig, initialBalance: Double = 100000.0, bistBalance: Double = 1000000.0) {
        self.config = config
        self.balance = initialBalance
        self.bistBalance = bistBalance
    }
    
    // MARK: - Portfolio Protocol
    
    func getEquity() -> Double {
        return balance + getUnrealizedValue(for: .usd)
    }
    
    func getBistEquity() -> Double {
        return bistBalance + getUnrealizedValue(for: .bist)
    }
    
    // MARK: - Computed Properties
    
    var openPositions: [Trade] {
        portfolio.filter { $0.isOpen }
    }
    
    var closedPositions: [Trade] {
        portfolio.filter { !$0.isOpen }
    }
    
    var totalPnL: Double {
        closedPositions.reduce(0) { $0 + $1.profit }
    }
    
    var openPositionCount: Int {
        openPositions.count
    }
    
    // MARK: - Portfolio Operations (Delegated from TradingViewModel)
    
    func addTrade(_ trade: Trade) {
        portfolio.append(trade)
        savePortfolio()
    }
    
    func updateTrade(id: UUID, update: (inout Trade) -> Void) {
        if let index = portfolio.firstIndex(where: { $0.id == id }) {
            update(&portfolio[index])
            savePortfolio()
        }
    }
    
    func closeTrade(id: UUID, exitPrice: Double, exitDate: Date = Date()) {
        if let index = portfolio.firstIndex(where: { $0.id == id }) {
            portfolio[index].isOpen = false
            portfolio[index].exitPrice = exitPrice
            portfolio[index].exitDate = exitDate
            savePortfolio()
        }
    }
    
    func getPosition(for symbol: String) -> [Trade] {
        portfolio.filter { $0.symbol == symbol && $0.isOpen }
    }
    
    func getTotalQuantity(for symbol: String) -> Double {
        getPosition(for: symbol).reduce(0) { $0 + $1.quantity }
    }
    
    // MARK: - Balance Operations
    
    enum Market {
        case usd
        case bist
    }
    
    func deductBalance(_ amount: Double, market: Market) {
        switch market {
        case .usd:
            balance -= amount
        case .bist:
            bistBalance -= amount
        }
    }
    
    func addBalance(_ amount: Double, market: Market) {
        switch market {
        case .usd:
            balance += amount
        case .bist:
            bistBalance += amount
        }
    }
    
    private func getUnrealizedValue(for market: Market) -> Double {
        let relevantTrades = openPositions.filter { trade in
            let isBist = trade.symbol.uppercased().hasSuffix(".IS")
            return market == .bist ? isBist : !isBist
        }
        
        return relevantTrades.reduce(0) { total, trade in
            let currentPrice = MarketDataStore.shared.quotes[trade.symbol]?.value?.currentPrice ?? trade.entryPrice
            return total + (trade.quantity * currentPrice)
        }
    }
    
    // MARK: - Transaction History
    
    func addTransaction(_ transaction: Transaction) {
        transactionHistory.append(transaction)
        saveTransactions()
    }
    
    // MARK: - Buy/Sell Protocol Methods (Async wrappers)
    
    func buy(symbol: String, quantity: Double, source: TradeSource, engine: AutoPilotEngine?) async throws {
        // Bu metot TradingViewModel.buy() çağrılarak doldurulacak
        // Şimdilik sadece protokol uyumluluğu için
        fatalError("Use TradingViewModel.buy() directly during transition period")
    }
    
    func sell(symbol: String, quantity: Double, source: TradeSource, reason: String?) async throws {
        // Bu metot TradingViewModel.sell() çağrılarak doldurulacak
        // Şimdilik sadece protokol uyumluluğu için
        fatalError("Use TradingViewModel.sell() directly during transition period")
    }
    
    // MARK: - Persistence
    
    private let portfolioKey = "portfolio_v3"
    private let balanceKey = "userBalance"
    private let bistBalanceKey = "bistBalance"
    private let transactionsKey = "transactionHistory_v2"
    
    private func loadSavedData() {
        // Portfolio
        if let data = UserDefaults.standard.data(forKey: portfolioKey),
           let decoded = try? JSONDecoder().decode([Trade].self, from: data) {
            self.portfolio = decoded
        }
        
        // Balance
        if let savedBalance = UserDefaults.standard.object(forKey: balanceKey) as? Double {
            self.balance = savedBalance
        }
        
        // BIST Balance
        if let savedBistBalance = UserDefaults.standard.object(forKey: bistBalanceKey) as? Double {
            self.bistBalance = savedBistBalance
        }
        
        // Transactions
        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            self.transactionHistory = decoded
        }
    }
    
    private func savePortfolio() {
        if let data = try? JSONEncoder().encode(portfolio) {
            UserDefaults.standard.set(data, forKey: portfolioKey)
        }
    }
    
    private func saveBalance() {
        UserDefaults.standard.set(balance, forKey: balanceKey)
    }
    
    private func saveBistBalance() {
        UserDefaults.standard.set(bistBalance, forKey: bistBalanceKey)
    }
    
    private func saveTransactions() {
        if let data = try? JSONEncoder().encode(transactionHistory) {
            UserDefaults.standard.set(data, forKey: transactionsKey)
        }
    }
}
