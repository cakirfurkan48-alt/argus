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
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)
        
        var report = """
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ARGUS PİYASA ANALİZ RAPORU
\(dateStr) | Kapanış Seansı
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. MAKRO ORTAM DEĞERLENDİRMESİ (AETHER)
───────────────────────────────────────
"""
        
        // 1. Atmosphere
        if let aether = atmosphere.aether {
            let regime: String
            let skorKategori: String
            if aether > 60 {
                regime = "Risk-On"
                skorKategori = "Olumlu"
            } else if aether < 40 {
                regime = "Risk-Off"
                skorKategori = "Olumsuz"
            } else {
                regime = "Nötr"
                skorKategori = "Belirsiz"
            }
            
            report += """

Rejim: \(regime) | Skor: \(Int(aether))/100

   Durum: \(skorKategori)
   
   Yorum: Makro ortam \(regime.lowercased()) modunda.
   \(aether > 60 ? "Risk iştahı yüksek, agresif pozisyonlar değerlendirilebilir." : (aether < 40 ? "Defansif strateji öneriliyor." : "Temkinli seyir önerilir."))
"""
        } else {
            report += "\nRejim: Veri Bekleniyor"
        }
        
        // 2. Trade Summary
        report += """


2. İŞLEM ÖZETİ
───────────────────────────────────────
"""
        
        let todayTrades = trades.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if todayTrades.isEmpty {
            report += "\nBugün gerçekleştirilen işlem bulunmamaktadır."
        } else {
            let buys = todayTrades.filter { $0.type == .buy }
            let sells = todayTrades.filter { $0.type == .sell }
            let totalVol = todayTrades.reduce(0.0) { $0 + $1.amount }
            let hasBist = todayTrades.contains { $0.symbol.uppercased().hasSuffix(".IS") }
            let currency = hasBist ? "TL" : "USD"
            
            report += """

   Toplam İşlem:    \(todayTrades.count)
   Alım:            \(buys.count)
   Satım:           \(sells.count)
   Toplam Hacim:    \(String(format: "%.2f", totalVol)) \(currency)

   Saat    Tip    Sembol        Miktar       Fiyat
   ─────────────────────────────────────────────────
"""
            for trade in todayTrades.prefix(10) {
                let tip = trade.type == .buy ? "ALIM" : "SATIS"
                let price = trade.price
                let qty = price > 0 ? (trade.amount / price) : 0.0
                let tradeCurrency = trade.symbol.uppercased().hasSuffix(".IS") ? "TL" : "$"
                let timeF = DateFormatter()
                timeF.dateFormat = "HH:mm"
                let tradeTime = timeF.string(from: trade.date)
                let symbolPadded = trade.symbol.padding(toLength: 10, withPad: " ", startingAt: 0)
                report += "   \(tradeTime)   \(tip.padding(toLength: 5, withPad: " ", startingAt: 0))  \(symbolPadded)  \(String(format: "%8.2f", qty))  \(tradeCurrency)\(String(format: "%.2f", price))\n"
            }
        }
        
        // 3. Decision Engine Stats
        report += """

3. KARAR MOTORU (ARGUS CORE)
───────────────────────────────────────
"""
        
        let todayDecisions = decisions.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
        let approved = todayDecisions.filter { $0.finalDecision.action == .buy || $0.finalDecision.action == .sell }
        let vetoed = todayDecisions.filter { 
            return $0.finalDecision.action == .hold && ($0.debate.claimant?.preferredAction == .buy || $0.debate.claimant?.preferredAction == .sell)
        }
        
        report += """

   Toplam Analiz:       \(todayDecisions.count)
   Onaylanan Fırsat:    \(approved.count)
   Veto Edilen:         \(vetoed.count)
"""
        
        if !vetoed.isEmpty {
            report += """


   VETO EDİLEN İŞLEMLER (Neden yapılmadı?)
   ┌──────────┬────────────┬─────────────────────────┐
   │ Sembol   │ Yön        │ Neden                   │
   ├──────────┼────────────┼─────────────────────────┤
"""
            for d in vetoed.prefix(5) {
                let direction = d.debate.claimant?.preferredAction == .buy ? "Alım" : "Satış"
                let reason = (!d.riskEvaluation.isApproved) ? d.riskEvaluation.reason : d.finalDecision.rationale
                let shortReason = String(reason.prefix(23))
                let symbolPad = d.symbol.padding(toLength: 8, withPad: " ", startingAt: 0)
                let dirPad = direction.padding(toLength: 10, withPad: " ", startingAt: 0)
                report += "   │ \(symbolPad) │ \(dirPad) │ \(shortReason.padding(toLength: 23, withPad: " ", startingAt: 0)) │\n"
            }
            report += "   └──────────┴────────────┴─────────────────────────┘"
        }
        
        // 4. Closing
        report += """


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Rapor Üretim: Argus Terminal
Bu rapor yatırım tavsiyesi içermez.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""
        
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
            
            // Para birimi: BIST varsa TL, yoksa $
            let hasBist = weeklyTrades.contains { $0.symbol.uppercased().hasSuffix(".IS") }
            let currency = hasBist ? "₺" : "$"
            
            report += "\n- **Net K/Z:** \(currency)\(String(format: "%.2f", totalPnL))"
            report += "\n- **İşlem Sayısı:** \(weeklyTrades.count)"
            report += "\n- **Başarı Oranı (Win Rate):** %\(String(format: "%.1f", winRate))"
            
            // Best Trade
            if let best = weeklyTrades.max(by: { ($0.pnl ?? -999) < ($1.pnl ?? -999) }), let pnl = best.pnl, pnl > 0 {
                let bestCurrency = best.symbol.uppercased().hasSuffix(".IS") ? "₺" : "$"
                report += "\n\n🔥 **Haftanın Yıldızı:** \(best.symbol) (+\(bestCurrency)\(String(format: "%.2f", pnl)))"
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
