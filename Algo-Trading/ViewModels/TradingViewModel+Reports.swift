import Foundation

extension TradingViewModel {
    @MainActor
    func refreshReports() async {
        // Prepare Data
        let trades = self.transactionHistory
        let decisions = Array(self.agoraTraces.values)
        let atmosphere = (aether: self.macroRating?.numericScore, demeter: self.demeterMatrix)
        
        let engine = ReportEngine.shared
        
        // 1. Daily Report
        self.dailyReport = await engine.generateDailyReport(
            date: Date(),
            trades: trades,
            decisions: decisions,
            atmosphere: atmosphere
        )
        
        // 2. Weekly Report
        self.weeklyReport = await engine.generateWeeklyReport(
            date: Date(),
            trades: trades,
            decisions: decisions
        )
    }
}
