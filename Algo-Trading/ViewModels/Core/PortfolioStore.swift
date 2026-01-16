import Foundation
import Combine
import SwiftUI

// MARK: - PortfolioStore (DEPRECATED - Facade to PortfolioEngine)
/// ⚠️ DEPRECATED: Bu sınıf artık PortfolioEngine'e yönlendiriyor.
/// Yeni kod PortfolioEngine.shared kullanmalıdır.
/// Bu facade eski bağımlılıklar için geriye uyumluluk sağlar.

@MainActor
final class PortfolioStore: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PortfolioStore()
    
    // MARK: - Delegation to PortfolioEngine
    private let engine = PortfolioEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties (Bridged from Engine)
    @Published private(set) var portfolio: [Trade] = []
    @Published private(set) var balance: Double = 100_000.0
    @Published private(set) var bistBalance: Double = 1_000_000.0
    @Published private(set) var transactionHistory: [Transaction] = []
    
    // MARK: - Init
    private init() {
        setupBridge()
    }
    
    private func setupBridge() {
        engine.$trades
            .receive(on: DispatchQueue.main)
            .assign(to: &$portfolio)
        
        engine.$globalBalance
            .receive(on: DispatchQueue.main)
            .assign(to: &$balance)
        
        engine.$bistBalance
            .receive(on: DispatchQueue.main)
            .assign(to: &$bistBalance)
        
        engine.$transactions
            .receive(on: DispatchQueue.main)
            .assign(to: &$transactionHistory)
    }
    
    // MARK: - Computed Properties (Delegated)
    
    var openPositions: [Trade] { engine.openTrades }
    var globalOpenPositions: [Trade] { engine.globalOpenTrades }
    var bistOpenPositions: [Trade] { engine.bistOpenTrades }
    
    // MARK: - Balance Helpers
    
    func availableBalance(for symbol: String) -> Double {
        engine.availableBalance(for: symbol)
    }
    
    // MARK: - Buy (Delegated)
    
    @discardableResult
    func buy(
        symbol: String,
        quantity: Double,
        price: Double,
        source: TradeSource = .user,
        engine: AutoPilotEngine? = nil,
        stopLoss: Double? = nil,
        takeProfit: Double? = nil,
        rationale: String? = nil,
        orionSnapshot: OrionComponentSnapshot? = nil
    ) -> Bool {
        self.engine.buy(
            symbol: symbol,
            quantity: quantity,
            price: price,
            source: source,
            engine: engine,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            rationale: rationale,
            orionSnapshot: orionSnapshot
        )
    }
    
    // MARK: - Sell (Delegated)
    
    func sell(tradeId: UUID, currentPrice: Double) -> Double? {
        engine.sell(tradeId: tradeId, currentPrice: currentPrice)
    }
    
    // MARK: - Portfolio Value Calculations (Delegated)
    
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
        engine.getGlobalEquity(quotes: quotes)
    }
    
    func getBistEquity(quotes: [String: Quote]) -> Double {
        engine.getBistEquity(quotes: quotes)
    }
    
    func getUnrealizedPnL(quotes: [String: Quote]) -> Double {
        engine.getGlobalUnrealizedPnL(quotes: quotes)
    }
    
    func getBistUnrealizedPnL(quotes: [String: Quote]) -> Double {
        engine.getBistUnrealizedPnL(quotes: quotes)
    }
    
    func getRealizedPnL() -> Double {
        engine.getRealizedPnL(currency: .USD)
    }
    
    func getBistRealizedPnL() -> Double {
        engine.getRealizedPnL(currency: .TRY)
    }
    
    // MARK: - Reset (Delegated)
    
    func reset() {
        engine.resetPortfolio()
    }
}
