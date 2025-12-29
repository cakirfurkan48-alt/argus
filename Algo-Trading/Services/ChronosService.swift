import Foundation

/// Chronos: The Keeper of Time.
/// Analyzes the "Age", "Energy", and "Exhaustion" of trends.
class ChronosService {
    static let shared = ChronosService()
    
    private init() {}
    
    func analyzeTime(symbol: String, candles: [Candle]) -> ChronosResult? {
        // Need decent history for SMA200 + Age check
        guard candles.count > 200 else { return nil }
        let sorted = candles.sorted { $0.date < $1.date }
        
        // 1. Trend Age Calculation
        let (age, verdict) = calculateTrendAge(candles: sorted)
        
        // 2. Aroon Calculation (25 period standard)
        let (aroonUp, aroonDown) = calculateAroon(candles: sorted, period: 25)
        
        // 3. Sequential Counter (Simplified TD)
        let (seqCount, seqComplete) = calculateSequential(candles: sorted)
        
        // 4. Time Score Calculation
        let score = calculateTimeScore(ageVerdict: verdict, aroonUp: aroonUp, aroonDown: aroonDown, seqCount: seqCount)
        
        return ChronosResult(
            symbol: symbol,
            trendAgeDays: age,
            ageVerdict: verdict,
            aroonUp: aroonUp,
            aroonDown: aroonDown,
            sequentialCount: seqCount,
            isSequentialComplete: seqComplete,
            timeScore: score
        )
    }
    
    // MARK: - Logic 1: Trend Age (The Curse)
    private func calculateTrendAge(candles: [Candle]) -> (Int, ChronosAgeVerdict) {
        let closes = candles.map { $0.close }
        guard let sma200 = sma(closes, 200) else { return (0, .unknown) }
        
        let currentPrice = closes.last ?? 0
        
        // If below SMA200, we consider it "Downtrend" or "Reset"
        if currentPrice < sma200 {
            return (0, .downtrend)
        }
        
        // Find the last time price crossed ABOVE SMA200
        // We iterate backwards
        var daysAbove = 0
        let count = candles.count
        
        // Pre-calculate SMA200 logic somewhat efficiently? 
        // Or just scan backwards checking dynamic SMA.
        // Full dynamic SMA scan is heavy. 
        // Heuristic: Check simple "Price > SMA200" condition backwards. 
        // Note: SMA200 changes every day. For strict accuracy we need rolling SMA.
        
        for i in 0..<count {
            let idx = count - 1 - i // From last to first
            if idx < 200 { break } // Needs 200 bars for SMA
            
            let slice = Array(closes[(idx-200)..<idx])
            let sliceSum = slice.reduce(0, +)
            let avg = sliceSum / 200.0
            let price = closes[idx]
            
            if price >= avg {
                daysAbove += 1
            } else {
                // Crossed below, trend start found
                break
            }
        }
        
        // Verdict
        // < 14 Days: Baby
        // 14 - 90 Days: Early
        // 90 - 270 Days: Prime
        // 270 - 500 Days: Old
        // > 500 Days: Ancient
        
        // Calendar days vs Trading days. 
        // 20 trading days ~ 1 month.
        // 250 trading days ~ 1 year.
        
        let verdict: ChronosAgeVerdict
        if daysAbove < 10 { verdict = .baby }
        else if daysAbove < 180 { verdict = .prime } // < 9 Months
        else if daysAbove < 360 { verdict = .old }   // < 1.5 Years
        else { verdict = .ancient }                  // > 1.5 Years
        
        return (daysAbove, verdict)
    }
    
    // MARK: - Logic 2: Aroon
    private func calculateAroon(candles: [Candle], period: Int) -> (Double, Double) {
        guard candles.count > period else { return (0, 0) }
        
        let slice = candles.suffix(period + 1) // Need lookback
        let highs = slice.map { $0.high }
        let lows = slice.map { $0.low }
        
        // Find index of highest high and lowest low in the last N periods
        // Arrays are suffix, so indices 0..period
        // Index 0 is oldest, Index period is newest (today)
        // Aroon formula uses "Days since high"
        
        var daysSinceHigh = 0
        var daysSinceLow = 0
        var maxH = -Double.infinity
        var minL = Double.infinity
        
        // Iterate backwards from today (last index) to period start
        let count = highs.count
        
        for i in 0..<period {
            let idx = count - 1 - i
            if highs[idx] > maxH {
                maxH = highs[idx]
                daysSinceHigh = i // 0 means high is today
            }
            if lows[idx] < minL {
                minL = lows[idx]
                daysSinceLow = i
            }
        }
        
        let up = ((Double(period) - Double(daysSinceHigh)) / Double(period)) * 100.0
        let down = ((Double(period) - Double(daysSinceLow)) / Double(period)) * 100.0
        
        return (up, down)
    }
    
    // MARK: - Logic 3: Sequential (Simplified)
    private func calculateSequential(candles: [Candle]) -> (Int, Bool) {
        // Look for 9 consecutive "Price > Price[4 bars ago]" (Buy Setup) 
        // or "Price < Price[4 bars ago]" (Sell Setup).
        // Returning simple counter. + for Buy Setup (Bullish Exhaustion?), - for Sell Setup?
        // Wait, Sequential Buy Setup (Price < Price[4]) implies Bottom Fishing (Bullish signal at 9).
        // Sequential Sell Setup (Price > Price[4]) implies Top Exhaustion (Bearish signal at 9).
        
        // Let's use standard signed int:
        // Positive (+): Consecutive closes HIGHER than 4 bars ago (Up Trend -> Exhaustion Risk)
        // Negative (-): Consecutive closes LOWER than 4 bars ago (Down Trend -> Bounce Opportunity)
        
        guard candles.count > 15 else { return (0, false) }
        let closes = candles.map { $0.close }
        
        var upCount = 0
        var downCount = 0
        
        // Check backwards from today
        // But Sequential resets if condition breaks. So strict sequence.
        
        // We calculate current sequence active TODAY.
        
        for i in 0..<13 { // Max check 13
            let idx = closes.count - 1 - i
            if idx < 4 { break }
            
            let current = closes[idx]
            let prior4 = closes[idx - 4]
            
            if current > prior4 {
                upCount += 1
                downCount = 0 // Reset other
            } else if current < prior4 {
                downCount += 1
                upCount = 0
            } else {
                break // Sequence broken
            }
        }
        
        if upCount > 0 {
            return (upCount, upCount >= 9) // 9 is "Setup", 13 is "Countdown" (simplified)
        } else {
            return (-downCount, downCount >= 9)
        }
    }
    
    // MARK: - Logic 4: Scoring
    private func calculateTimeScore(ageVerdict: ChronosAgeVerdict, aroonUp: Double, aroonDown: Double, seqCount: Int) -> Double {
        var score = 50.0 // Neutral start
        
        // Age Impact
        switch ageVerdict {
        case .prime: score += 20 // Ideal
        case .baby: score -= 10 // Volatile
        case .old: score -= 10 // Tired
        case .ancient: score -= 20 // Danger
        case .downtrend: score -= 10
        case .unknown: break
        }
        
        // Aroon Impact
        // AroonUp > 70 implies Strong Trend
        if aroonUp > 70 && aroonDown < 30 {
            score += 15
        } else if aroonDown > 70 && aroonUp < 30 {
            score -= 15
        } else if aroonUp < 50 && aroonDown < 50 {
            score -= 5 // Dead market
        }
        
        // Sequential Impact (Exhaustion)
        // High +Count (e.g. 9 or 13) means "Up Trend Exhausted" -> Risk -> Lower Score
        if seqCount >= 9 {
            score -= 20 // Danger Signal
        } else if seqCount <= -9 {
            score += 20 // Oversold Signal (Opportunity)
        }
        
        // Safety Clamps
        return max(0, min(100, score))
    }
    
    // Helper
    private func sma(_ data: [Double], _ period: Int) -> Double? {
        guard data.count >= period else { return nil }
        return data.suffix(period).reduce(0, +) / Double(period)
    }
}
