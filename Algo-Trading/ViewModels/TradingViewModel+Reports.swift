import Foundation

extension TradingViewModel {
    @MainActor
    func refreshReports() async {
        // Prepare Data
        let trades = self.transactionHistory
        let decisions = Array(self.agoraTraces.values)
        let atmosphere = (aether: self.macroRating?.numericScore, demeter: self.demeterMatrix)
        
        // BIST Trades (TL işlemleri - .IS suffix)
        let bistTrades = trades.filter { $0.symbol.uppercased().hasSuffix(".IS") }
        let bistDecisions = decisions.filter { $0.symbol.uppercased().hasSuffix(".IS") }
        
        // Global Trades (USD işlemleri)
        let globalTrades = trades.filter { !$0.symbol.uppercased().hasSuffix(".IS") }
        let globalDecisions = decisions.filter { !$0.symbol.uppercased().hasSuffix(".IS") }
        
        let engine = ReportEngine.shared
        
        // 1. Global Daily Report
        self.dailyReport = await engine.generateDailyReport(
            date: Date(),
            trades: globalTrades,
            decisions: globalDecisions,
            atmosphere: atmosphere
        )
        
        // 2. Global Weekly Report
        self.weeklyReport = await engine.generateWeeklyReport(
            date: Date(),
            trades: globalTrades,
            decisions: globalDecisions
        )
        
        // 3. BIST Daily Report
        self.bistDailyReport = await engine.generateDailyReport(
            date: Date(),
            trades: bistTrades,
            decisions: bistDecisions,
            atmosphere: atmosphere
        )
        
        // 4. BIST Weekly Report
        self.bistWeeklyReport = await engine.generateWeeklyReport(
            date: Date(),
            trades: bistTrades,
            decisions: bistDecisions
        )
    }
}

