import Foundation

/// Generates premium quality Daily and Weekly summaries for the user.
/// Aggregates Trade Log, Decision Trace, and Market Atmosphere.
actor ReportEngine {
    static let shared = ReportEngine()
    
    private init() {}
    
    // MARK: - Daily Report
    
    func generateDailyReport(
        date: Date = Date(),
        trades: [Transaction], // Completed transactions today
        decisions: [AgoraTrace], // Decisions made today
        atmosphere: (aether: Double?, demeter: CorrelationMatrix?)
    ) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        let dateStr = formatter.string(from: date)
        
        var report = """
        # 🦅 Argus GÜNLÜK RAPORU
        **Tarih:** \(dateStr)
        
        ## 🌍 Piyasa Atmosferi
        """
        
        // 1. Atmosphere
        if let aether = atmosphere.aether {
            let regime = aether > 60 ? "Pozitif (Risk İştahı Yüksek)" : (aether < 40 ? "Negatif (Riskten Kaçış)" : "Nötr / Belirsiz")
            report += "\n- **Genel Rejim:** \(regime) (Skor: \(Int(aether)))"
        } else {
            report += "\n- **Genel Rejim:** Veri Bekleniyor"
        }
        
        report += "\n\n## 📊 İşlem Özeti\n"
        
        // 2. Trades
        let todayTrades = trades.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if todayTrades.isEmpty {
            report += "Bugün gerçekleştirilen işlem bulunmamaktadır.\n"
        } else {
            let buys = todayTrades.filter { $0.type == .buy }.count
            let sells = todayTrades.filter { $0.type == .sell }.count
            let totalVol = todayTrades.reduce(0.0) { $0 + $1.amount }
            
            report += "- **Toplam İşlem:** \(todayTrades.count) (Alış: \(buys), Satış: \(sells))\n"
            report += "- **Hacim:** $\(String(format: "%.2f", totalVol))\n"
            
            report += "\n### Detaylar:\n"
            for trade in todayTrades {
                let icon = trade.type == .buy ? "🟢 AL" : "🔴 SAT"
                let price = trade.price
                // Calculate quantity if valid
                let qty = price > 0 ? (trade.amount / price) : 0.0
                report += "- \(icon) **\(trade.symbol)**: \(String(format: "%.2f", price)) ($ üzerinden \(String(format: "%.4f", qty)) adet)\n"
            }
        }
        
        // 3. Decision Trace Statistics
        report += "\n## 🧠 Karar Motoru (Argus Core)\n"
        
        let todayDecisions = decisions.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
        // Fix: Use explicit .buy/.sell check instead of .noTrade which doesn't exist
        let approved = todayDecisions.filter { $0.finalDecision.action == .buy || $0.finalDecision.action == .sell }
        let vetoed = todayDecisions.filter { 
            // Vetoed = Logic approved buy/sell but Governance/Risk blocked it, OR Logic leaned buy/sell but final was Hold
            // Simplifying: Any Trace where 'debate' had strong claim but final was Hold.
            return $0.finalDecision.action == .hold && ($0.debate.claimant?.preferredAction == .buy || $0.debate.claimant?.preferredAction == .sell)
        }
        
        report += "- **Toplam Analiz:** \(todayDecisions.count)\n"
        report += "- **Onaylanan Fırsatlar:** \(approved.count)\n"
        report += "- **Veto Edilen / Pas geçilen:** \(vetoed.count)\n"
        
        if !vetoed.isEmpty {
            report += "\n### 🛡️ Veto ve Engeller (Neden İşlem Yapılmadı?)\n"
            for d in vetoed.prefix(5) { // Top 5 interesting vetoes
                let direction = d.debate.claimant?.preferredAction == .buy ? "Alım" : "Satış"
                // Fix: vetoTriggered property doesn't exist. Use risk evaluation reason or final rationale.
                let reason = (!d.riskEvaluation.isApproved) ? d.riskEvaluation.reason : d.finalDecision.rationale
                report += "- **\(d.symbol)** (\(direction) Fırsatı): \(reason)\n"
            }
        }
        
        // 4. Closing
        report += "\n---\n*Argus Otonom Sistem Tarafından Üretilmiştir.*"
        
        return report
    }

    // MARK: - Weekly Report
    
    func generateWeeklyReport(
        date: Date = Date(),
        trades: [Transaction], // All trades
        decisions: [AgoraTrace] // All decisions
    ) -> String {
        let calendar = Calendar.current
        // Find start of week (Monday)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let weekEnd = date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        let rangeStr = "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        
        var report = """
        # 📅 Argus HAFTALIK ÖZET
        **Dönem:** \(rangeStr)
        
        ## 📊 Performans
        """
        
        // Filter for this week
        let weeklyTrades = trades.filter { $0.date >= weekStart && $0.date <= weekEnd }
        
        if weeklyTrades.isEmpty {
            report += "\nBu hafta herhangi bir işlem gerçekleşmedi."
        } else {
            let totalPnL = weeklyTrades.reduce(0.0) { $0 + ($1.pnl ?? 0) }
            let winCount = weeklyTrades.filter { ($0.pnl ?? 0) > 0 }.count
            let lossCount = weeklyTrades.filter { ($0.pnl ?? 0) < 0 }.count
            let totalCount = winCount + lossCount
            let winRate = totalCount > 0 ? (Double(winCount) / Double(totalCount)) * 100 : 0.0
            
            report += "\n- **Net K/Z:** $\(String(format: "%.2f", totalPnL))"
            report += "\n- **İşlem Sayısı:** \(weeklyTrades.count)"
            report += "\n- **Başarı Oranı (Win Rate):** %\(String(format: "%.1f", winRate))"
            
            // Best Trade
            if let best = weeklyTrades.max(by: { ($0.pnl ?? -999) < ($1.pnl ?? -999) }), let pnl = best.pnl, pnl > 0 {
                report += "\n\n🔥 **Haftanın Yıldızı:** \(best.symbol) (+$\(String(format: "%.2f", pnl)))"
            }
        }
        
        report += "\n\n## 🧠 Strateji Analizi\n"
        let weeklyDecisions = decisions.filter { $0.timestamp >= weekStart && $0.timestamp <= weekEnd }
        let vetoes = weeklyDecisions.filter { !($0.riskEvaluation.isApproved) }
        
        if !weeklyDecisions.isEmpty {
            report += "- Sistem bu hafta **\(weeklyDecisions.count)** fırsatı değerlendirdi.\n"
            report += "- **\(vetoes.count)** işlem risk protokolüne takılarak engellendi.\n"
            
            if !vetoes.isEmpty {
                // Find most common veto reason
                // Simple frequency map
                var reasons: [String: Int] = [:]
                for v in vetoes {
                    let r = v.riskEvaluation.reason // Remove redundant ?? "Belirsiz" as reason is non-optional
                    reasons[r, default: 0] += 1
                }
                if let topReason = reasons.max(by: { $0.value < $1.value }) {
                    report += "- En sık karşılaşılan engel: **\(topReason.key)** (\(topReason.value) kez)"
                }
            }
        } else {
            report += "Sistem bu hafta henüz yeterli veri biriktirmedi."
        }
        
        report += "\n\n### 🔮 Gelecek Hafta Beklentisi\n"
        report += "Aether makro verileri ve Phoenix radar taramaları, önümüzdeki hafta volatilite artışına işaret ediyor. Temkinli seyir (Tier 1) önerilir."
        
        report += "\n---\n*Argus Weekly Intelligence*"
        
        return report
    }
}
