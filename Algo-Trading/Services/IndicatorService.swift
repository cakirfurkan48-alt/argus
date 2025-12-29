import Foundation

// MARK: - Indicator Service
// Teknik analiz indikatörlerini hesaplar.

struct IndicatorService {
    
    // MARK: - SMA (Simple Moving Average)
    static func calculateSMA(values: [Double], period: Int) -> [Double?] {
        var smaValues = [Double?](repeating: nil, count: values.count)
        guard values.count >= period else { return smaValues }
        
        for i in (period - 1)..<values.count {
            let slice = values[(i - period + 1)...i]
            let sum = slice.reduce(0, +)
            smaValues[i] = sum / Double(period)
        }
        return smaValues
    }
    
    // MARK: - RSI (Relative Strength Index)
    static func calculateRSI(values: [Double], period: Int = 14) -> [Double?] {
        var rsiValues = [Double?](repeating: nil, count: values.count)
        guard values.count > period else { return rsiValues }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        // İlk değişimleri hesapla
        for i in 1..<values.count {
            let diff = values[i] - values[i-1]
            gains.append(max(diff, 0))
            losses.append(max(-diff, 0))
        }
        
        // İlk ortalama gain/loss
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        
        // İlk RSI
        if avgLoss == 0 {
            rsiValues[period] = 100
        } else {
            let rs = avgGain / avgLoss
            rsiValues[period] = 100 - (100 / (1 + rs))
        }
        
        // Smoothed RSI
        for i in (period + 1)..<values.count {
            let currentGain = gains[i-1]
            let currentLoss = losses[i-1]
            
            avgGain = ((avgGain * Double(period - 1)) + currentGain) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + currentLoss) / Double(period)
            
            if avgLoss == 0 {
                rsiValues[i] = 100
            } else {
                let rs = avgGain / avgLoss
                rsiValues[i] = 100 - (100 / (1 + rs))
            }
        }
        
        return rsiValues
    }
    
    // MARK: - MACD (Moving Average Convergence Divergence)
    static func calculateMACD(values: [Double], fastPeriod: Int = 12, slowPeriod: Int = 26, signalPeriod: Int = 9) -> (macd: [Double?], signal: [Double?], histogram: [Double?]) {
        let fastEMA = calculateEMA(values: values, period: fastPeriod)
        let slowEMA = calculateEMA(values: values, period: slowPeriod)
        
        var macdLine = [Double?](repeating: nil, count: values.count)
        
        for i in 0..<values.count {
            if let f = fastEMA[i], let s = slowEMA[i] {
                macdLine[i] = f - s
            }
        }
        
        // Signal Line (MACD Line'ın EMA'sı)
        // MACD line'daki nil değerleri atlayarak hesaplamak lazım ama basitlik için
        // nil olmayan ilk değerden itibaren EMA başlatacağız.
        
        // MACD Line'ı non-optional diziye çevirip EMA hesaplayıp geri maplemek zor olabilir.
        // Basit bir yaklaşım:
        let validMACDIndices = macdLine.indices.filter { macdLine[$0] != nil }
        guard !validMACDIndices.isEmpty else {
            return ([Double?](repeating: nil, count: values.count), [Double?](repeating: nil, count: values.count), [Double?](repeating: nil, count: values.count))
        }
        
        let firstValidIndex = validMACDIndices.first!
        let validValues = macdLine[firstValidIndex...].compactMap { $0 }
        
        let signalLineValid = calculateEMA(values: validValues, period: signalPeriod)
        
        var signalLine = [Double?](repeating: nil, count: values.count)
        var histogram = [Double?](repeating: nil, count: values.count)
        
        for (index, value) in signalLineValid.enumerated() {
            let originalIndex = firstValidIndex + index
            signalLine[originalIndex] = value
            
            if let m = macdLine[originalIndex], let s = value {
                histogram[originalIndex] = m - s
            }
        }
        
        return (macdLine, signalLine, histogram)
    }
    
    // MARK: - EMA Helper
    static func calculateEMA(values: [Double], period: Int) -> [Double?] {
        var emaValues = [Double?](repeating: nil, count: values.count)
        guard values.count >= period else { return emaValues }
        
        let k = 2.0 / Double(period + 1)
        
        // İlk EMA = SMA
        let initialSlice = values.prefix(period)
        var ema = initialSlice.reduce(0, +) / Double(period)
        emaValues[period - 1] = ema
        
        for i in period..<values.count {
            ema = (values[i] * k) + (ema * (1 - k))
            emaValues[i] = ema
        }
        
        return emaValues
    }
    
    // MARK: - Bollinger Bands
    static func calculateBollingerBands(values: [Double], period: Int = 20, stdDevMultiplier: Double = 2.0) -> (upper: [Double?], middle: [Double?], lower: [Double?]) {
        let sma = calculateSMA(values: values, period: period)
        var upper = [Double?](repeating: nil, count: values.count)
        var lower = [Double?](repeating: nil, count: values.count)
        
        for i in (period - 1)..<values.count {
            guard let middleVal = sma[i] else { continue }
            
            let slice = values[(i - period + 1)...i]
            let variance = slice.map { pow($0 - middleVal, 2.0) }.reduce(0, +) / Double(period)
            let stdDev = sqrt(variance)
            
            upper[i] = middleVal + (stdDev * stdDevMultiplier)
            lower[i] = middleVal - (stdDev * stdDevMultiplier)
        }
        
        return (upper, sma, lower)
    }
    // MARK: - ATR (Average True Range)
    static func calculateATR(candles: [Candle], period: Int = 14) -> [Double?] {
        var atrValues = [Double?](repeating: nil, count: candles.count)
        guard candles.count > period else { return atrValues }
        
        var trValues: [Double] = []
        
        for i in 0..<candles.count {
            let high = candles[i].high
            let low = candles[i].low
            
            if i == 0 {
                trValues.append(high - low)
            } else {
                let prevClose = candles[i-1].close
                let tr = max(high - low, max(abs(high - prevClose), abs(low - prevClose)))
                trValues.append(tr)
            }
        }
        
        // İlk ATR (SMA)
        let initialSlice = trValues.prefix(period)
        var atr = initialSlice.reduce(0, +) / Double(period)
        atrValues[period - 1] = atr
        
        // Sonraki ATR (Smoothed)
        for i in period..<candles.count {
            atr = ((atr * Double(period - 1)) + trValues[i]) / Double(period)
            atrValues[i] = atr
        }
        
        return atrValues
    }
    
    // MARK: - ADX (Average Directional Index)
    static func calculateADX(candles: [Candle], period: Int = 14) -> [Double?] {
        var tr = [Double](repeating: 0.0, count: candles.count)
        var plusDM = [Double](repeating: 0.0, count: candles.count)
        var minusDM = [Double](repeating: 0.0, count: candles.count)
        
        for i in 1..<candles.count {
            let currentHigh = candles[i].high
            let currentLow = candles[i].low
            let prevClose = candles[i-1].close
            let prevHigh = candles[i-1].high
            let prevLow = candles[i-1].low
            
            tr[i] = max(currentHigh - currentLow, max(abs(currentHigh - prevClose), abs(currentLow - prevClose)))
            
            let upMove = currentHigh - prevHigh
            let downMove = prevLow - currentLow
            
            if upMove > downMove && upMove > 0 {
                plusDM[i] = upMove
            }
            if downMove > upMove && downMove > 0 {
                minusDM[i] = downMove
            }
        }
        
        func wilderSmooth(values: [Double]) -> [Double] {
            var smoothed = [Double](repeating: 0.0, count: values.count)
            guard values.count > period else { return smoothed }
            smoothed[period] = values[1...period].reduce(0, +)
            for i in (period + 1)..<values.count {
                smoothed[i] = smoothed[i-1] - (smoothed[i-1] / Double(period)) + values[i]
            }
            return smoothed
        }
        
        let trSmooth = wilderSmooth(values: tr)
        let plusDMSmooth = wilderSmooth(values: plusDM)
        let minusDMSmooth = wilderSmooth(values: minusDM)
        
        var adxValues = [Double?](repeating: nil, count: candles.count)
        var dxValues = [Double](repeating: 0.0, count: candles.count)
        
        for i in period..<candles.count {
            if trSmooth[i] != 0 {
                let plusDI = 100 * (plusDMSmooth[i] / trSmooth[i])
                let minusDI = 100 * (minusDMSmooth[i] / trSmooth[i])
                if (plusDI + minusDI) != 0 {
                    dxValues[i] = 100 * abs(plusDI - minusDI) / (plusDI + minusDI)
                }
            }
        }
        
        if candles.count > 2 * period {
            let firstADXIndex = 2 * period
            let slice = dxValues[(period + 1)...firstADXIndex]
            adxValues[firstADXIndex] = slice.reduce(0, +) / Double(period)
            
            for i in (firstADXIndex + 1)..<candles.count {
                if let prev = adxValues[i-1] {
                     adxValues[i] = ((prev * Double(period - 1)) + dxValues[i]) / Double(period)
                }
            }
        }
        
        return adxValues
    }

    // MARK: - Parabolic SAR
    static func calculateSAR(candles: [Candle], acceleration: Double = 0.02, maximum: Double = 0.2) -> [Double?] {
        var sarValues = [Double?](repeating: nil, count: candles.count)
        guard candles.count > 2 else { return sarValues }
        
        var af = acceleration
        var isLong = true
        var sar = candles[0].low
        var ep = candles[0].high
        
        sarValues[0] = sar
        
        for i in 1..<candles.count {
            sarValues[i] = sar
            
            if isLong {
                sar = sar + af * (ep - sar)
                sar = min(sar, candles[i-1].low)
                if i > 1 { sar = min(sar, candles[i-2].low) }
                
                if candles[i].low < sar {
                    isLong = false
                    sar = ep
                    ep = candles[i].low
                    af = acceleration
                } else {
                    if candles[i].high > ep {
                        ep = candles[i].high
                        af = min(af + acceleration, maximum)
                    }
                }
            } else {
                sar = sar + af * (ep - sar)
                sar = max(sar, candles[i-1].high)
                if i > 1 { sar = max(sar, candles[i-2].high) }
                
                if candles[i].high > sar {
                    isLong = true
                    sar = ep
                    ep = candles[i].high
                    af = acceleration
                } else {
                    if candles[i].low < ep {
                        ep = candles[i].low
                        af = min(af + acceleration, maximum)
                    }
                }
            }
        }
        return sarValues
    }

    // MARK: - Stochastic Oscillator
    static func calculateStochastic(candles: [Candle], kPeriod: Int = 14, dPeriod: Int = 3) -> (k: [Double?], d: [Double?]) {
        var kValues = [Double?](repeating: nil, count: candles.count)
        var dValues = [Double?](repeating: nil, count: candles.count)
        guard candles.count >= kPeriod else { return (kValues, dValues) }
        
        // Calculate %K
        for i in (kPeriod - 1)..<candles.count {
            let slice = candles[(i - kPeriod + 1)...i]
            let highestHigh = slice.map { $0.high }.max() ?? 0
            let lowestLow = slice.map { $0.low }.min() ?? 0
            let currentClose = candles[i].close
            
            if highestHigh - lowestLow != 0 {
                let k = ((currentClose - lowestLow) / (highestHigh - lowestLow)) * 100
                kValues[i] = k
            } else {
                kValues[i] = 50 // Flat market fallback
            }
        }
        
        // Calculate %D (SMA of %K)
        // %K dizisindeki nil değerleri atlayarak hesapla
        let validKIndices = kValues.indices.filter { kValues[$0] != nil }
        if !validKIndices.isEmpty {
            let firstValidIndex = validKIndices.first!
            let validKs = kValues[firstValidIndex...].compactMap { $0 }
            let dSma = calculateSMA(values: validKs, period: dPeriod)
            
            for (index, value) in dSma.enumerated() {
                dValues[firstValidIndex + index] = value
            }
        }
        
        return (kValues, dValues)
    }
    
    // MARK: - CCI (Commodity Channel Index)
    static func calculateCCI(candles: [Candle], period: Int = 20) -> [Double?] {
        var cciValues = [Double?](repeating: nil, count: candles.count)
        guard candles.count >= period else { return cciValues }
        
        let tpValues = candles.map { ($0.high + $0.low + $0.close) / 3.0 }
        let smaTP = calculateSMA(values: tpValues, period: period)
        
        for i in (period - 1)..<candles.count {
            guard let sma = smaTP[i] else { continue }
            
            let slice = tpValues[(i - period + 1)...i]
            let meanDeviation = slice.map { abs($0 - sma) }.reduce(0, +) / Double(period)
            
            if meanDeviation != 0 {
                cciValues[i] = (tpValues[i] - sma) / (0.015 * meanDeviation)
            } else {
                cciValues[i] = 0
            }
        }
        
        return cciValues
    }
    
    // MARK: - Ichimoku Cloud
    struct IchimokuResult {
        let tenkanSen: [Double?]
        let kijunSen: [Double?]
        let senkouSpanA: [Double?]
        let senkouSpanB: [Double?]
        let chikouSpan: [Double?]
    }
    
    static func calculateIchimoku(candles: [Candle]) -> IchimokuResult {
        let tenkanPeriod = 9
        let kijunPeriod = 26
        let senkouBPeriod = 52
        let displacement = 26
        
        let count = candles.count
        var tenkan = [Double?](repeating: nil, count: count)
        var kijun = [Double?](repeating: nil, count: count)
        var spanA = [Double?](repeating: nil, count: count)
        var spanB = [Double?](repeating: nil, count: count)
        var chikou = [Double?](repeating: nil, count: count)
        
        // Helper to get mid price of range
        func getMid(period: Int, index: Int) -> Double? {
            guard index >= period - 1 else { return nil }
            let slice = candles[(index - period + 1)...index]
            let high = slice.map { $0.high }.max() ?? 0
            let low = slice.map { $0.low }.min() ?? 0
            return (high + low) / 2
        }
        
        for i in 0..<count {
            // Tenkan-sen
            tenkan[i] = getMid(period: tenkanPeriod, index: i)
            
            // Kijun-sen
            kijun[i] = getMid(period: kijunPeriod, index: i)
            
            // Senkou Span A (Shifted forward)
            if i >= displacement, let t = tenkan[i - displacement], let k = kijun[i - displacement] {
                spanA[i] = (t + k) / 2
            }
            
            // Senkou Span B (Shifted forward)
            if i >= displacement, let midB = getMid(period: senkouBPeriod, index: i - displacement) {
                spanB[i] = midB
            }
            
            // Chikou Span (Shifted backward)
            if i + displacement < count {
                chikou[i] = candles[i + displacement].close
            }
        }
        
        return IchimokuResult(tenkanSen: tenkan, kijunSen: kijun, senkouSpanA: spanA, senkouSpanB: spanB, chikouSpan: chikou)
    }
}
