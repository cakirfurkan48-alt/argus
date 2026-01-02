import Foundation

final class OrionAnalysisService: @unchecked Sendable {
    static let shared = OrionAnalysisService()
    private let lock = NSLock()
    
    // MARK: - CACHING - Performans optimizasyonu
    private var cache: [String: (result: OrionScoreResult, candleCount: Int, timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 300 // 5 dakika cache
    
    private init() {}
    
    // MARK: - Shared Helpers (Used by Athena etc.)
    
    func calculateVWAP(candles: [Candle]) -> Double? {
        guard !candles.isEmpty else { return nil }
        var cumPV = 0.0
        var cumVol = 0.0
        for candle in candles {
            let typicalPrice = (candle.high + candle.low + candle.close) / 3.0
            cumPV += typicalPrice * Double(candle.volume)
            cumVol += Double(candle.volume)
        }
        return cumVol == 0 ? nil : cumPV / cumVol
    }
    
    struct PivotPoints {
        let p: Double, r1: Double, s1: Double
    }
    
    func calculatePivots(candles: [Candle]) -> PivotPoints? {
        guard candles.count >= 2 else { return nil }
        let prev = candles[candles.count - 2]
        let p = (prev.high + prev.low + prev.close) / 3.0
        return PivotPoints(p: p, r1: (2 * p) - prev.low, s1: (2 * p) - prev.high)
    }
    
    func calculateATR(candles: [Candle], period: Int = 14) -> Double {
        guard candles.count >= period + 1 else { return 0.0 }
        let sorted = candles.sorted { $0.date < $1.date }
        var trueRanges: [Double] = []
        
        for i in 1..<sorted.count {
            let h = sorted[i].high
            let l = sorted[i].low
            let pc = sorted[i-1].close
            trueRanges.append(max(h - l, max(abs(h - pc), abs(l - pc))))
        }
        
        let recentTRs = trueRanges.suffix(period)
        return recentTRs.isEmpty ? 0.0 : recentTRs.reduce(0, +) / Double(recentTRs.count)
    }
    
    // MARK: - Orion 3.0 Core Logic
    
    /// Main entry point for Orion Technical Score (V3 Architecture - Rebalanced)
    func calculateOrionScore(symbol: String, candles: [Candle], spyCandles: [Candle]? = nil) -> OrionScoreResult? {
        // CACHE CHECK - Aynı sembol ve benzer veri için cache kullan
        lock.lock()
        if let cached = cache[symbol],
           cached.candleCount == candles.count,
           Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            lock.unlock()
            return cached.result
        }
        lock.unlock()
        
        // Need decent history
        guard candles.count > 50 else { return nil }
        let sorted = candles.sorted { $0.date < $1.date }
        
        // === DYNAMIC WEIGHTS FROM TUNING STORE ===
        // Get tuned config for this symbol (or global default)
        let config = OrionV2TuningStore.shared.getConfig(symbol: symbol)
        
        // Convert weights to max scores (out of 100)
        let structureMax = config.structureWeight * 100.0
        let trendMax = config.trendWeight * 100.0
        let momentumMax = config.momentumWeight * 100.0
        let patternMax = config.patternWeight * 100.0
        let volatilityMax = config.volatilityWeight * 100.0
        
        // --- 1. STRUCTURE ---
        let structRes = OrionStructureService.shared.analyzeStructure(candles: sorted)
        let structScore = structRes?.score ?? 50.0
        let structWeighted = (structScore / 100.0) * structureMax
        
        // --- 2. TREND - Now includes MACD ---
        let (trendRaw, trendDesc) = calculateTrendLeg(candles: sorted) // Max 30
        let (rsScore, rsDesc, rsAvail) = calculateRSLeg(stock: sorted, spy: spyCandles) // Max 15
        let (macdScore, _, macdHist) = calculateMACDForTrend(candles: sorted) // Max 10
        
        let trendWeighted: Double
        if rsAvail {
            // Full calculation: Trend(30) + RS(15) + MACD(10) = 55 → scale to trendMax
            let combinedTrend = trendRaw + rsScore + macdScore
            trendWeighted = (combinedTrend / 55.0) * trendMax
        } else {
            // No SPY: Trend(30) + MACD(10) = 40 → scale to trendMax
            let combinedTrend = trendRaw + macdScore
            trendWeighted = (combinedTrend / 40.0) * trendMax
        }
        
        // --- 3. MOMENTUM - RSI + Volume only (no MACD) ---
        let (momRaw, momDesc, rsiValue) = calculateMomentumLegNoMACD(candles: sorted) // Max 15 (RSI only)
        let (volRaw, volDesc) = calculateVolLiquidityLeg(candles: sorted) // Max 15
        
        // RSI(15) + Volume(15) = 30 → scale to momentumMax
        let combinedMomRaw = momRaw + volRaw
        let momWeighted = (combinedMomRaw / 30.0) * momentumMax
        
        // --- 4. PATTERN ---
        let patternRes = OrionPatternService.shared.analyzePatterns(candles: sorted, context: structRes?.activeZone)
        let patternScore = patternRes.score
        let patternWeighted = (patternScore / 100.0) * patternMax
        
        // --- 5. VOLATILITY ---
        let (volScore, _) = calculateVolatilityLeg(candles: sorted)
        let volatilityWeighted = (volScore / 100.0) * volatilityMax
        
        // --- AGGREGATION ---
        var finalScore = structWeighted + trendWeighted + momWeighted + patternWeighted + volatilityWeighted
        
        // Synergy: Reduced bonus (8%)
        if let s = structRes, s.trendState == .uptrend, s.activeZone != nil {
            finalScore *= 1.08
        }
        
        // MARK: - BIST MODÜLÜ (Turquoise)
        // Sadece BIST hisselerinde çalışır, diğerlerine dokunmaz
        var bistAnalysisDesc: String? = nil
        if SymbolResolver.shared.isBistSymbol(symbol) || symbol.uppercased().hasSuffix(".IS") {
            // Orion BIST Engine (Class based, synchronous call safe)
            let bistDecision = OrionBistEngine.shared.analyze(symbol: symbol, candles: sorted)
            
            // BIST skoru normal skora etki eder (±10 puan aralığında)
            let bistModifier: Double
            switch bistDecision.action {
            case .buy:
                bistModifier = 10.0
            case .sell:
                bistModifier = -10.0
            case .hold:
                bistModifier = 0.0
            }
            
            finalScore += bistModifier
            bistAnalysisDesc = "🇹🇷 BIST: \(bistDecision.action.rawValue) | \(bistDecision.winningProposal?.reasoning ?? "")"
        }
        
        // Cap
        finalScore = min(100.0, max(0.0, finalScore))
        
        let components = OrionComponentScores(
            trend: trendWeighted, // Scaled to 25
            momentum: momWeighted, // Scaled to 25
            relativeStrength: rsScore, // Legacy field (kept raw)
            structure: structWeighted, // NEW
            pattern: patternWeighted, // NEW
            volatility: volRaw, // Legacy field
            
            // Detailed Indicators
            rsi: rsiValue,
            macdHistogram: macdHist,
            
            isRsAvailable: rsAvail,
            trendDesc: "\(trendDesc) | \(rsDesc)",
            momentumDesc: "\(momDesc) | \(volDesc)",
            structureDesc: structRes?.description ?? "Yapı Nötr",
            patternDesc: bistAnalysisDesc ?? patternRes.description, // BIST varsa BIST açıklaması göster
            rsDesc: rsDesc,
            volDesc: volDesc
        )
        
        let result = OrionScoreResult(
            symbol: symbol,
            score: finalScore,
            components: components,
            verdict: getVerdict(score: finalScore),
            generatedAt: Date()
        )
        
        // CACHE SAVE - Sonucu cache'e kaydet
        lock.lock()
        cache[symbol] = (result: result, candleCount: candles.count, timestamp: Date())
        lock.unlock()
        
        return result
    }
    
    /// Async wrapper for background execution - prevents main thread hang
    func calculateOrionScoreAsync(symbol: String, candles: [Candle], spyCandles: [Candle]? = nil) async -> OrionScoreResult? {
        // Offload to background thread
        return await Task.detached(priority: .userInitiated) {
            return self.calculateOrionScore(symbol: symbol, candles: candles, spyCandles: spyCandles)
        }.value
    }
    
    // MARK: - Leg 1: Trend Quality (30p)
    private func calculateTrendLeg(candles: [Candle]) -> (Double, String) {
        // Requirements: SMA20, 50, 200
        let closes = candles.map { $0.close }
        let current = closes.last ?? 0
        
        guard let sma20 = sma(closes, 20),
              let sma50 = sma(closes, 50),
              let sma200 = sma(closes, 200) else {
            return (0.0, "Yetersiz Veri (SMA)")
        }
        
        var rawScore = 0.0
        
        // 1. Long Term Bias (Max 10 pts)
        if current > sma200 {
            rawScore += 10.0
        } else {
            // Partial credit if close to reclaiming (within 2%)
            let distTo200 = (sma200 - current) / sma200
            if distTo200 < 0.02 { rawScore += 5.0 }
        }
        
        // 2. Alignment (Max 10 pts)
        if sma20 > sma50 && sma50 > sma200 {
            rawScore += 10.0 // Full Bull Alignment
        } else if sma20 > sma50 {
            rawScore += 7.0 // Short term bull (Golden Cross Area)
        } else if sma20 > sma200 {
            rawScore += 3.0 // Mixed
        }
        
        // 3. Momentum Strength / Dynamic Positioning (Max 10 pts)
        // Score based on Price position relative to SMA20 (The "Trader's MA")
        let dist20 = (current - sma20) / sma20
        
        if dist20 > 0 {
            // Price is above SMA20.
            // Linear scale: 0% diff -> 5 pts, 5% diff -> 10 pts (Strong Trend)
            // But if > 15%, it might be extended (handled in penalty)
            let momentumFactor = min(1.0, dist20 / 0.05) // Caps at 5%
            rawScore += 5.0 + (5.0 * momentumFactor)
        } else {
            // Price below SMA20 (Pullback or Downtrend)
            // If SMA20 is above SMA50, it's a "Buyable Pullback" -> Give some points
            if sma20 > sma50 {
                // Closer to SMA20 is better than Far below
                let pullbackDepth = abs(dist20)
                if pullbackDepth < 0.03 { rawScore += 6.0 } // Shallow pullback
                else if pullbackDepth < 0.07 { rawScore += 3.0 } // Deep pullback
            }
        }
        
        // 4. Over-Extension Penalty (Dynamic)
        // If Price is > 20% above SMA50, risky.
        let dist50 = (current - sma50) / sma50
        if dist50 > 0.20 {
            let excess = (dist50 - 0.20) * 100.0 // e.g. 0.22 -> 2.0
            rawScore -= min(5.0, excess)
        }
        
        let finalScore = max(0, min(30, rawScore))
        let desc = String(format: "Trend: %.1f/30 (D: %.1f%%)", finalScore, dist20 * 100)
        
        return (finalScore, desc)
    }
    
    // MARK: - Leg 2: Momentum (20p)
    private func calculateMomentumLeg(candles: [Candle]) -> (Double, String) {
        // RSI(14) (Max 12 pts)
        guard let rsiVal = rsi(candles, 14) else { return (10.0, "Veri Yok") }
        
        var score = 0.0
        var notes: [String] = []
        
        // RSI Dynamic Scoring
        if rsiVal >= 50 && rsiVal <= 70 {
            // Strong Bull Zone
            // Map 50->6 pts, 70->12 pts
            let strength = (rsiVal - 50) / 20.0 // 0 to 1
            score += 6.0 + (6.0 * strength)
            notes.append("RSI Güçlü (\(Int(rsiVal)))")
        } else if rsiVal > 70 {
            // Overbought check
            if rsiVal > 80 {
                score += 4.0 // Dangerous but strong
                notes.append("RSI Şişkin (\(Int(rsiVal)))")
            } else {
                score += 10.0 // High momentum
                notes.append("RSI Yüksek (\(Int(rsiVal)))")
            }
        } else if rsiVal >= 40 {
             // Weak/Neutral 40-50
             // Map 40->3 pts, 50->6 pts
             let recovery = (rsiVal - 40) / 10.0
             score += 3.0 + (3.0 * recovery)
             notes.append("RSI Nötr (\(Int(rsiVal)))")
        } else {
            // Oversold < 40
            // FIX: Bounce potential for mean reversion strategies
            if rsiVal < 30 {
                score += 6.0  // Strong bounce potential
                notes.append("RSI Aşırı Satım (Bounce?)")
            } else {
                score += 4.0  // Mild oversold
                notes.append("RSI Zayıf")
            }
        }
        
        // MACD (Max 8 pts)
        let (_, finalSignal, hist) = macd(candles)
        
        if let h = hist, let signal = finalSignal {
             // MACD Strength
             // If Hist is positive -> Good.
             // If Hist is increasing -> Better.
             
             if h > 0 {
                 score += 5.0
                 // Rising Histogram?
                 // We need previous hist... complicated with current helper.
                 // Simplified: Amplitude check or just assume > 0 is good.
                 if signal > 0 { score += 3.0 } // Both above zero line
                 else { score += 1.0 } // Early reversal
                 notes.append("MACD Pozitif")
             } else {
                  // FIX: Don't give 0 when MACD negative - that's too harsh
                  if h > signal { 
                      score += 4.0 // Improving - crossing up
                      notes.append("MACD Toparlanıyor")
                  } else { 
                      score += 2.0 // At least give some baseline
                      notes.append("MACD Negatif")
                  }
             }
        }
        
        return (min(score, 20.0), notes.joined(separator: ", "))
    }
    
    // MARK: - Leg 3: Relative Strength (15p)
    private func calculateRSLeg(stock: [Candle], spy: [Candle]?) -> (Double, String, Bool) {
        guard let spy = spy, !spy.isEmpty, stock.count > 30, spy.count > 30 else {
            return (0.0, "Kıyaslama verisi (SPY) yok", false)
        }
        
        // 30 Bar Lookback
        let sNow = stock.last!.close
        let sOld = stock[stock.count - 30].close
        let sRet = (sNow - sOld) / sOld
        
        let mNow = spy.last!.close
        // Need to align dates ideally, but for MVP assuming daily aligned arrays roughly
        // Safe approach: Find spy candle nearest to stock[count-30].date
        // Or simplified: Just take last - 30 if arrays match.
        // Assuming spy array is also recent daily.
        let mOld = spy[spy.count - 30].close
        let mRet = (mNow - mOld) / mOld
        
        let delta = sRet - mRet
        let deltaPct = delta * 100.0 // e.g. +5.0 (%)
        
        var score = 0.0
        var desc = ""
        
        if deltaPct >= 5.0 {
            score = 15.0
            desc = "Endekten %\(String(format: "%.1f", deltaPct)) daha iyi performans."
        } else if deltaPct >= 0.0 {
            score = 10.0
            desc = "Endekse paralel veya hafif pozitif (+\(String(format: "%.1f", deltaPct))%)."
        } else if deltaPct > -5.0 {
            score = 7.0
            desc = "Endeksin hafif gerisinde (%\(String(format: "%.1f", deltaPct)))."
        } else {
            score = 3.0
            desc = "Endeksten ciddi negatif ayrışma (%\(String(format: "%.1f", deltaPct)))."
        }
        
        return (score, desc, true)
    }
    
    // MARK: - Leg 4: Volatility & Liquidity (15p)
    private func calculateVolLiquidityLeg(candles: [Candle]) -> (Double, String) {
        // A) Liquidity (8p) - Logarithmic Scale
        let suffix = candles.suffix(20)
        let avgVol = suffix.map { Double($0.volume) }.reduce(0, +) / Double(suffix.count)
        let price = candles.last?.close ?? 0
        let dollarVol = avgVol * price
        
        var scoreLiq = 0.0
        if dollarVol > 1_000_000 {
            // Log10(1M) = 6. Log10(100M) = 8.
            let logVal = log10(dollarVol)
            // Map 6.0 -> 2 pts, 8.0 -> 8 pts
            let normalized = (logVal - 6.0) / 2.0 // 0 to 1 range approx (for 1M to 100M)
            scoreLiq = 2.0 + (6.0 * min(1.0, max(0.0, normalized)))
        } else {
            scoreLiq = 1.0 // Very illiquid
        }
        
        // B) Volatility (7p) - ATR% Bell Curve
        let atr = calculateATR(candles: candles, period: 14)
        let atrPct = (atr / price) * 100.0
        
        // Target: 2.5% is ideal.
        // Formula: 7 * e^(-0.5 * ((x - 2.5)/1.5)^2) -> Gaussian?
        // Or simpler: Linear distance
        let dist = abs(atrPct - 2.5)
        var scoreVol = 0.0
        if dist < 4.0 {
            // Max 7 pts at dist=0. 0 pts at dist=4 (ATR=6.5% or ATR=-1.5%)
            scoreVol = 7.0 * (1.0 - (dist / 4.0))
        }
        
        let total = min(15.0, scoreLiq + scoreVol)
        let desc = "Vol: %\(String(format: "%.1f", atrPct)), Hacim: $\(formatMoney(dollarVol))"
        
        return (total, desc)
    }
    
    // MARK: - NEW LEG: MACD for Trend (Max 10p)
    private func calculateMACDForTrend(candles: [Candle]) -> (Double, String, Double?) {
        let (macdLine, signal, hist) = macd(candles)
        
        guard let h = hist, let sig = signal, let _ = macdLine else {
            return (5.0, "MACD Veri Yok", nil)
        }
        
        var score = 0.0
        var desc = ""
        
        // MACD as trend indicator
        if h > 0 {
            // Positive histogram = bullish trend
            score += 6.0
            if sig > 0 {
                score += 4.0 // Strong bullish (both above zero)
                desc = "MACD Güçlü Trend"
            } else {
                score += 2.0 // Early bullish
                desc = "MACD Erken Trend"
            }
        } else {
            // Negative histogram
            if h > sig {
                score += 5.0 // Improving
                desc = "MACD Toparlanıyor"
            } else {
                score += 2.0 // Weak
                desc = "MACD Zayıf"
            }
        }
        
        return (min(10.0, score), desc, h)
    }
    
    // MARK: - NEW LEG: Momentum without MACD (Max 15p - RSI only)
    private func calculateMomentumLegNoMACD(candles: [Candle]) -> (Double, String, Double?) {
        guard let rsiVal = rsi(candles, 14) else { return (7.5, "Veri Yok", nil) }
        
        var score = 0.0
        var notes: [String] = []
        
        // RSI Dynamic Scoring (Max 15 pts)
        if rsiVal >= 50 && rsiVal <= 70 {
            // Strong Bull Zone
            let strength = (rsiVal - 50) / 20.0
            score += 8.0 + (7.0 * strength) // 8-15 pts
            notes.append("RSI Güçlü (\(Int(rsiVal)))")
        } else if rsiVal > 70 {
            // Overbought
            if rsiVal > 80 {
                score += 6.0 // Too extended
                notes.append("RSI Şişkin (\(Int(rsiVal)))")
            } else {
                score += 12.0 // High momentum
                notes.append("RSI Yüksek (\(Int(rsiVal)))")
            }
        } else if rsiVal >= 40 {
            // Neutral 40-50
            let recovery = (rsiVal - 40) / 10.0
            score += 5.0 + (3.0 * recovery) // 5-8 pts
            notes.append("RSI Nötr (\(Int(rsiVal)))")
        } else {
            // Oversold < 40
            if rsiVal < 30 {
                score += 8.0 // Strong bounce potential
                notes.append("RSI Aşırı Satım (Bounce?)")
            } else {
                score += 5.0 // Mild oversold
                notes.append("RSI Zayıf")
            }
        }
        
        return (min(15.0, score), notes.joined(separator: ", "), rsiVal)
    }
    
    // MARK: - NEW LEG: Volatility (Max 100 base, scaled to 5%)
    private func calculateVolatilityLeg(candles: [Candle]) -> (Double, Bool) {
        // Bollinger Squeeze Detection
        let closes = candles.map { $0.close }
        guard closes.count >= 20 else { return (50.0, false) }
        
        let price = closes.last ?? 0
        let atr = calculateATR(candles: candles, period: 14)
        
        // Bollinger Band Width
        guard let sma20 = sma(closes, 20) else { return (50.0, false) }
        
        let recentCloses = Array(closes.suffix(20))
        let variance = recentCloses.map { pow($0 - sma20, 2) }.reduce(0, +) / 20.0
        let stdDev = sqrt(variance)
        let bbWidth = (stdDev * 2) / sma20 * 100.0 // Percentage
        
        // Historical BB Width for squeeze detection
        var historicalWidths: [Double] = []
        for i in 20..<min(closes.count, 120) {
            let slice = Array(closes[(i-20)..<i])
            if let sliceSMA = sma(slice, 20) {
                let sliceVar = slice.map { pow($0 - sliceSMA, 2) }.reduce(0, +) / 20.0
                let sliceStd = sqrt(sliceVar)
                historicalWidths.append((sliceStd * 2) / sliceSMA * 100.0)
            }
        }
        
        let avgWidth = historicalWidths.isEmpty ? bbWidth : historicalWidths.reduce(0, +) / Double(historicalWidths.count)
        let isSqueeze = bbWidth < avgWidth * 0.7 // Current width is 30% below average
        
        var score = 50.0
        
        // Squeeze = potential breakout
        if isSqueeze {
            score += 30.0
        }
        
        // Optimal volatility (not too high, not too low)
        let atrPct = (atr / price) * 100.0
        if atrPct > 1.5 && atrPct < 4.0 {
            score += 20.0 // Goldilocks zone
        } else if atrPct < 1.0 {
            score += 10.0 // Low vol, potential squeeze
        } else if atrPct > 6.0 {
            score -= 20.0 // Too volatile
        }
        
        return (min(100.0, max(0.0, score)), isSqueeze)
    }

    
    // MARK: - Utilities
    
    private func sma(_ data: [Double], _ period: Int) -> Double? {
        guard data.count >= period else { return nil }
        return data.suffix(period).reduce(0, +) / Double(period)
    }
    
    private func rsi(_ candles: [Candle], _ period: Int) -> Double? {
        // SSoT: IndicatorService kullanılıyor
        return IndicatorService.lastRSI(candles: candles, period: period)
    }
    
    private func macd(_ candles: [Candle]) -> (Double?, Double?, Double?) {
        // SSoT: IndicatorService kullanılıyor
        return IndicatorService.lastMACD(candles: candles)
    }
    
    private func formatMoney(_ val: Double) -> String {
        if val > 1_000_000 { return "\(String(format: "%.1f", val/1_000_000))M" }
        return "\(Int(val))"
    }
    
    private func getVerdict(score: Double) -> String {
        switch score {
        case 85...100: return "A+ Fırsat (Nadir)"
        case 70..<85: return "Güçlü Alım"
        case 50..<70: return "Nötr / Tut"
        case 30..<50: return "Zayıf / İzle"
        default: return "Uzak Dur"
        }
    }
}
