import Foundation
import Combine

// MARK: - PortfolioManager (DEPRECATED - Facade to PortfolioEngine)
/// ⚠️ DEPRECATED: Bu sınıf artık PortfolioEngine'e yönlendiriyor.
/// Yeni kod PortfolioEngine.shared kullanmalıdır.
/// Bu facade eski bağımlılıklar için geriye uyumluluk sağlar.

@MainActor
final class PortfolioManager: ObservableObject, PortfolioManaging {
    
    // MARK: - Singleton
    static let shared = PortfolioManager()
    
    // MARK: - Delegation to PortfolioEngine
    private let engine = PortfolioEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties (Bridged from Engine)
    @Published private(set) var portfolio: [Trade] = []
    @Published var balance: Double = 100_000.0
    @Published var bistBalance: Double = 1_000_000.0
    @Published private(set) var transactionHistory: [Transaction] = []
    
    // MARK: - State
    var lastTradeTimes: [String: Date] = [:]
    
    // MARK: - Dependencies
    private let feeModel = FeeModel.shared
    private let config: TradingConfig
    
    // MARK: - Initialization
    
    private init() {
        self.config = TradingConfig.default
        setupBridge()
    }
    
    init(config: TradingConfig, initialBalance: Double = 100000.0, bistBalance: Double = 1000000.0) {
        self.config = config
        self.balance = initialBalance
        self.bistBalance = bistBalance
        setupBridge()
    }
    
    private func setupBridge() {
        engine.$trades
            .receive(on: DispatchQueue.main)
            .assign(to: &$portfolio)
        
        engine.$globalBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                self?.balance = newBalance
            }
            .store(in: &cancellables)
        
        engine.$bistBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                self?.bistBalance = newBalance
            }
            .store(in: &cancellables)
        
        engine.$transactions
            .receive(on: DispatchQueue.main)
            .assign(to: &$transactionHistory)
    }
    
    // MARK: - Portfolio Protocol
    
    func getEquity() -> Double {
        return balance + getUnrealizedValue(for: .usd)
    }
    
    func getBistEquity() -> Double {
        return bistBalance + getUnrealizedValue(for: .bist)
    }
    
    // MARK: - Computed Properties
    
    var openPositions: [Trade] { engine.openTrades }
    var closedPositions: [Trade] { engine.closedTrades }
    var totalPnL: Double { engine.getRealizedPnL() }
    var openPositionCount: Int { engine.openTrades.count }
    
    // MARK: - Portfolio Operations (Delegated)
    
    func addTrade(_ trade: Trade) {
        // Delegated to engine via buy
        print("⚠️ PortfolioManager.addTrade deprecated - use PortfolioEngine.buy")
    }
    
    func updateTrade(id: UUID, update: (inout Trade) -> Void) {
        // Not supported in new architecture
        print("⚠️ PortfolioManager.updateTrade deprecated")
    }
    
    func closeTrade(id: UUID, exitPrice: Double, exitDate: Date = Date()) {
        _ = engine.sell(tradeId: id, currentPrice: exitPrice)
    }
    
    func getPosition(for symbol: String) -> [Trade] {
        engine.getPosition(for: symbol)
    }
    
    func getTotalQuantity(for symbol: String) -> Double {
        engine.getTotalQuantity(for: symbol)
    }
    
    // MARK: - Balance Operations
    
    enum Market {
        case usd
        case bist
    }
    
    func deductBalance(_ amount: Double, market: Market) {
        // Not directly supported - balances managed by engine
        print("⚠️ PortfolioManager.deductBalance deprecated - use PortfolioEngine.buy")
    }
    
    func addBalance(_ amount: Double, market: Market) {
        // Not directly supported - balances managed by engine
        print("⚠️ PortfolioManager.addBalance deprecated - use PortfolioEngine.sell")
    }
    
    private func getUnrealizedValue(for market: Market) -> Double {
        let relevantTrades = engine.openTrades.filter { trade in
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
        // Not directly supported - transactions managed by engine
        print("⚠️ PortfolioManager.addTransaction deprecated")
    }
    
    // MARK: - Buy/Sell Protocol Methods
    
    func buy(symbol: String, quantity: Double, source: TradeSource, engine: AutoPilotEngine?) async throws {
        let price = MarketDataStore.shared.quotes[symbol]?.value?.currentPrice ?? 0
        guard price > 0 else { throw PortfolioError.useViewModelDirectly }
        _ = self.engine.buy(symbol: symbol, quantity: quantity, price: price, source: source, engine: engine)
    }
    
    func sell(symbol: String, quantity: Double, source: TradeSource, reason: String?) async throws {
        // Find trade and sell
        if let trade = self.engine.openTrades.first(where: { $0.symbol == symbol }) {
            let price = MarketDataStore.shared.quotes[symbol]?.value?.currentPrice ?? trade.entryPrice
            _ = self.engine.sell(tradeId: trade.id, currentPrice: price, reason: reason)
        }
    }
    
    // MARK: - Persistence (No-op, handled by engine)
    
    func loadSavedData() { }
    func savePortfolio() { }
    func saveBalance() { }
    func saveBistBalance() { }
    func saveTransactions() { }
}

// MARK: - Portfolio Errors
enum PortfolioError: LocalizedError {
    case useViewModelDirectly
    
    var errorDescription: String? {
        switch self {
        case .useViewModelDirectly:
            return "Bu işlem TradingViewModel üzerinden yapılmalıdır."
        }
    }
}
