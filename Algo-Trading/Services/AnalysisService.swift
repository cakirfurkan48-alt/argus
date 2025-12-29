import Foundation

class AnalysisService {
    static let shared = AnalysisService()
    
    private init() {}
    
    private let timeSeriesModel = TimeSeriesModelService()
    
    // MARK: - Main Analysis Methods
    
    // MARK: - Enums
    enum MarketRegime {
        case trending // Trend var (Yükseliş veya Düşüş) -> MACD, SMA kullan
        case ranging  // Yatay piyasa -> RSI, Bollinger, Stochastic kullan
        case unknown
    }

    func calculateCompositeScore(candles: [Candle]) -> CompositeScore {
        // ... (Existing code)
        guard !candles.isEmpty else {
            return CompositeScore(totalScore: 0, breakdown: [:], sentiment: .hold)
        }
        
        var totalScore: Double = 0
        var breakdown: [String: Double] = [:]
        var weightSum: Double = 0
        
        // Helper to add score
        func add(name: String, score: Double, weight: Double) {
            totalScore += score * weight
            breakdown[name] = score
            weightSum += weight
        }
        
        // 1. RSI (Weight: 1.5) - Momentum
        let rsi = calculateRSIValue(candles: candles)
        var rsiScore: Double = 0
        if rsi < 30 { rsiScore = 100 }      // Strong Buy
        else if rsi < 40 { rsiScore = 50 }  // Buy
        else if rsi > 70 { rsiScore = -100 } // Strong Sell
        else if rsi > 60 { rsiScore = -50 }  // Sell
        add(name: "RSI", score: rsiScore, weight: 1.5)
        
        // 2. MACD (Weight: 2.0) - Trend Following
        let (macdLine, _, histogram) = calculateMACD(candles: candles)
        var macdScore: Double = 0
        if let hist = histogram {
            if hist > 0 && hist > (macdLine ?? 0) * 0.1 { macdScore = 80 } // Strong Momentum Up
            else if hist > 0 { macdScore = 40 }
            else if hist < 0 && hist < (macdLine ?? 0) * 0.1 { macdScore = -80 } // Strong Momentum Down
            else if hist < 0 { macdScore = -40 }
        }
        add(name: "MACD", score: macdScore, weight: 2.0)
        
        // 3. Bollinger Bands (Weight: 1.0) - Volatility / Mean Reversion
        let (upper, lower) = calculateBollingerValues(candles: candles)
        var bbScore: Double = 0
        if let last = candles.last?.close, let l = lower, let u = upper {
            if last < l { bbScore = 90 } // Oversold (Buy)
            else if last > u { bbScore = -90 } // Overbought (Sell)
        }
        add(name: "Bollinger", score: bbScore, weight: 1.0)
        
        // 4. SMA Trend (Weight: 1.5) - Trend Direction
        let (sma20, sma50) = calculateSMAValues(candles: candles)
        var smaScore: Double = 0
        if let s20 = sma20, let s50 = sma50 {
            if s20 > s50 { smaScore = 70 } // Golden Cross / Uptrend
            else { smaScore = -70 } // Death Cross / Downtrend
        }
        add(name: "Trend (SMA)", score: smaScore, weight: 1.5)
        
        // 5. Stochastic (Weight: 1.0) - Momentum
        let (k, d) = calculateStochastic(candles: candles)
        var stochScore: Double = 0
        if let kVal = k, let dVal = d {
            if kVal < 20 && dVal < 20 { stochScore = 80 } // Oversold
            else if kVal > 80 && dVal > 80 { stochScore = -80 } // Overbought
        }
        add(name: "Stochastic", score: stochScore, weight: 1.0)
        
        // 6. CCI (Weight: 0.8) - Cyclical
        let cci = calculateCCI(candles: candles)
        var cciScore: Double = 0
        if let c = cci {
            if c < -100 { cciScore = 60 }
            else if c > 100 { cciScore = -60 }
        }
        add(name: "CCI", score: cciScore, weight: 0.8)
        
        // 7. ADX (Weight: 0.5) - Trend Strength (Multiplier)
        // ADX doesn't give direction, only strength. We use it to amplify trend scores.
        let adx = calculateADX(candles: candles)
        if let adxVal = adx, adxVal > 25 {
            // Trend is strong, boost SMA and MACD scores
            // (Simplified logic for score aggregation)
            totalScore *= 1.1 // Boost total score by 10% if trend is strong
        }
        
        // Final Calculation
        let finalScore = weightSum > 0 ? totalScore / weightSum : 0
        let clampedScore = max(-100, min(100, finalScore))
        
        // Determine Sentiment
        let sentiment: SignalAction
        if clampedScore >= 40 { sentiment = .buy }
        else if clampedScore <= -40 { sentiment = .sell }
        else { sentiment = .hold }
        
        return CompositeScore(totalScore: clampedScore, breakdown: breakdown, sentiment: sentiment)
    }
    
    func detectMarketRegime(candles: [Candle]) -> MarketRegime {
        // ADX > 25 ise Trend, değilse Yatay (Ranging) kabul edelim.
        guard let adx = calculateADX(candles: candles) else { return .unknown }
        return adx > 25 ? .trending : .ranging
    }
    
    func generateDetailedSignals(candles: [Candle]) -> [Signal] {
        var signals: [Signal] = []
        
        // 1. Existing Indicator Strategies
        if let s = analyzeRSI(candles: candles) { signals.append(s) }
        if let s = analyzeMACD(candles: candles) { signals.append(s) }
        if let s = analyzeBollinger(candles: candles) { signals.append(s) }
        if let s = analyzeSMA(candles: candles) { signals.append(s) }
        if let s = analyzeStochastic(candles: candles) { signals.append(s) }
        if let s = analyzeCCI(candles: candles) { signals.append(s) }
        if let s = analyzeADX(candles: candles) { signals.append(s) }
        if let s = analyzeWilliamsR(candles: candles) { signals.append(s) }
        
        // 2. New Time Series Model Strategy
        if let s = timeSeriesModel.analyze(candles: candles) { signals.append(s) }
        
        return signals
    }
    
    // MARK: - Analyzers (V6 with Education)
    
    private func analyzeRSI(candles: [Candle]) -> Signal? {
        let val = calculateRSIValue(candles: candles)
        var action: SignalAction = .hold
        var reason = "RSI \(String(format: "%.0f", val)) ile nötr bölgede."
        
        if val < 30 { action = .buy; reason = "RSI aşırı satım (Oversold) bölgesinde (<30). Tepki yükselişi beklenebilir." }
        else if val > 70 { action = .sell; reason = "RSI aşırı alım (Overbought) bölgesinde (>70). Düzeltme gelebilir." }
        
        return Signal(
            strategyName: "RSI (Göreceli Güç Endeksi)",
            action: action,
            confidence: 85,
            reason: reason,
            indicatorValues: ["RSI": String(format: "%.1f", val)],
            logic: "Fiyatın ne kadar hızlı değiştiğini ölçer.",
            successContext: "Yatay piyasalarda dip/tepe yakalamada iyidir.",
            simplifiedExplanation: "RSI, bir hissenin çok mu hızlı yükseldiğini (aşırı pahalı) yoksa çok mu sert düştüğünü (aşırı ucuz) anlamamıza yarar.\n\n• 30'un altı: Hisse çok ucuzladı, yakında yükselebilir (AL Fırsatı).\n• 70'in üzeri: Hisse çok şişti, yakında düşebilir (SAT Sinyali).\n• 30-70 arası: Normal seyir, beklemede kal."
        )
    }
    
    private func analyzeMACD(candles: [Candle]) -> Signal? {
        let (macd, signal, hist) = calculateMACD(candles: candles)
        guard let m = macd, let s = signal, let h = hist else { return nil }
        
        var action: SignalAction = .hold
        var reason = "MACD çizgileri birbirine yakın, belirgin bir momentum yok."
        
        if h > 0 && m > s { action = .buy; reason = "MACD Sinyal çizgisini yukarı kesti (Bullish Crossover). Pozitif momentum." }
        else if h < 0 && m < s { action = .sell; reason = "MACD Sinyal çizgisini aşağı kesti (Bearish Crossover). Negatif momentum." }
        
        return Signal(
            strategyName: "MACD (Trend Takipçisi)",
            action: action,
            confidence: 90,
            reason: reason,
            indicatorValues: ["MACD": String(format: "%.2f", m), "Signal": String(format: "%.2f", s), "Hist": String(format: "%.2f", h)],
            logic: "Trendin yönünü ve gücünü gösterir.",
            successContext: "Trend yapan piyasalarda en güvenilir araçtır.",
            simplifiedExplanation: "MACD, trendin yönünü (yukarı mı aşağı mı) ve gücünü anlamamıza yarayan bir trafik polisi gibidir.\n\n• Mavi çizgi turuncuyu YUKARI keserse: Yükseliş başlıyor demektir (AL).\n• Mavi çizgi turuncuyu AŞAĞI keserse: Düşüş başlıyor demektir (SAT).\n• Çizgiler birbirinden uzaklaşıyorsa trend güçleniyor demektir."
        )
    }
    
    private func analyzeBollinger(candles: [Candle]) -> Signal? {
        let (u, l) = calculateBollingerValues(candles: candles)
        guard let upper = u, let lower = l, let price = candles.last?.close else { return nil }
        
        var action: SignalAction = .hold
        var reason = "Fiyat bantlar arasında normal seyrediyor."
        
        if price < lower { action = .buy; reason = "Fiyat alt bandı kırdı. İstatistiksel olarak banda geri dönüş beklenir." }
        else if price > upper { action = .sell; reason = "Fiyat üst bandı kırdı. Aşırı uzama var, banda dönüş beklenebilir." }
        
        return Signal(
            strategyName: "Bollinger Bantları",
            action: action,
            confidence: 80,
            reason: reason,
            indicatorValues: ["Upper": String(format: "%.2f", upper), "Lower": String(format: "%.2f", lower)],
            logic: "Fiyatın 'normal' sınırlarını çizer.",
            successContext: "Ani fiyat hareketlerini ve dönüşleri yakalar.",
            simplifiedExplanation: "Bollinger Bantları, fiyatın hareket ettiği bir 'yol' gibidir. Fiyat genelde bu yolun içinde kalır.\n\n• Fiyat ALT çizgiye değerse: Çok düştü, tepki verip yükselebilir (AL).\n• Fiyat ÜST çizgiye değerse: Çok yükseldi, kar satışı gelebilir (SAT).\n• Bantlar daralırsa: Fırtına öncesi sessizlik, yakında sert bir hareket olacak demektir."
        )
    }
    
    private func analyzeSMA(candles: [Candle]) -> Signal? {
        let (s20, s50) = calculateSMAValues(candles: candles)
        guard let short = s20, let long = s50 else { return nil }
        
        let action: SignalAction = short > long ? .buy : .sell
        let reason = short > long ? "Kısa vade (SMA 20), uzun vade (SMA 50) üzerinde. Yükseliş trendi." : "Kısa vade (SMA 20), uzun vade (SMA 50) altında. Düşüş trendi."
        
        return Signal(
            strategyName: "SMA Trend (Hareketli Ortalamalar)",
            action: action,
            confidence: 75,
            reason: reason,
            indicatorValues: ["SMA20": String(format: "%.2f", short), "SMA50": String(format: "%.2f", long)],
            logic: "Fiyatın ortalama yönünü gösterir.",
            successContext: "Büyük trendleri (Boğa/Ayı) belirlemede kullanılır.",
            simplifiedExplanation: "Hareketli ortalamalar, fiyatın genel gidişatını gösterir. Kısa vadeli ortalama (Hızlı), uzun vadeli ortalamayı (Yavaş) geçerse sinyal üretir.\n\n• Golden Cross (Altın Kesişim): Hızlı olan Yavaşı YUKARI keserse büyük bir yükseliş başlayabilir.\n• Death Cross (Ölüm Kesişimi): Hızlı olan Yavaşı AŞAĞI keserse büyük bir düşüş başlayabilir."
        )
    }
    
    private func analyzeStochastic(candles: [Candle]) -> Signal? {
        let (k, d) = calculateStochastic(candles: candles)
        guard let kVal = k, let dVal = d else { return nil }
        
        var action: SignalAction = .hold
        var reason = "Stokastik nötr bölgede."
        
        if kVal < 20 { action = .buy; reason = "Stokastik < 20 (Aşırı Satım). Dip seviyeler." }
        else if kVal > 80 { action = .sell; reason = "Stokastik > 80 (Aşırı Alım). Tepe seviyeler." }
        
        return Signal(
            strategyName: "Stochastic Osilatör",
            action: action,
            confidence: 80,
            reason: reason,
            indicatorValues: ["%K": String(format: "%.1f", kVal), "%D": String(format: "%.1f", dVal)],
            logic: "Kapanışın fiyat aralığındaki yerini ölçer.",
            successContext: "RSI gibi dönüşleri yakalamak için idealdir.",
            simplifiedExplanation: "Stokastik, RSI'ın daha hassas bir kardeşidir. Fiyatın gün içindeki en yüksek ve en düşük seviyelerine göre nerede kapandığına bakar.\n\n• 20'nin altı: Fiyat çok ucuzladı, alıcılar gelebilir.\n• 80'in üzeri: Fiyat çok pahalandı, satıcılar gelebilir."
        )
    }
    
    private func analyzeCCI(candles: [Candle]) -> Signal? {
        guard let cci = calculateCCI(candles: candles) else { return nil }
        
        var action: SignalAction = .hold
        var reason = "CCI normal aralıkta (-100 ile +100)."
        
        if cci < -100 { action = .buy; reason = "CCI < -100. Fiyat ortalamadan çok saptı (Aşırı Satım)." }
        else if cci > 100 { action = .sell; reason = "CCI > 100. Fiyat ortalamadan çok saptı (Aşırı Alım)." }
        
        return Signal(
            strategyName: "CCI (Emtia Kanal Endeksi)",
            action: action,
            confidence: 70,
            reason: reason,
            indicatorValues: ["CCI": String(format: "%.1f", cci)],
            logic: "Fiyatın ortalamadan sapmasını ölçer.",
            successContext: "Yeni trend başlangıçlarını tespit etmede kullanılır.",
            simplifiedExplanation: "CCI, fiyatın istatistiksel olarak 'normalden' ne kadar saptığını ölçer.\n\n• -100'ün altı: Fiyat anormal derecede düştü, tepki verebilir.\n• +100'ün üzeri: Fiyat anormal derecede yükseldi, düzeltme gelebilir.\n• 0 çizgisi: Denge noktasıdır."
        )
    }
    
    private func analyzeADX(candles: [Candle]) -> Signal? {
        guard let adx = calculateADX(candles: candles) else { return nil }
        
        // ADX is non-directional, so we default to HOLD but give info
        let reason = adx > 25 ? "ADX > 25. Güçlü bir trend var (Yönü diğer indikatörlere sor)." : "ADX < 25. Piyasa yatay veya trend zayıf."
        
        return Signal(
            strategyName: "ADX (Trend Gücü)",
            action: .hold, // ADX alone doesn't say Buy/Sell
            confidence: 60,
            reason: reason,
            indicatorValues: ["ADX": String(format: "%.1f", adx)],
            logic: "Trendin GÜCÜNÜ ölçer, yönünü değil.",
            successContext: "Trendin devam edip etmeyeceğini anlamak için kullanılır.",
            simplifiedExplanation: "ADX, arabanın hız göstergesi gibidir. Nereye gittiğini (yukarı/aşağı) söylemez, sadece ne kadar HIZLI gittiğini söyler.\n\n• 25'in altı: Piyasa kararsız, yatay seyrediyor. İşlem yapmak riskli olabilir.\n• 25'in üzeri: Güçlü bir trend var (Yükseliş veya Düşüş). Trend yönünde işlem açmak mantıklı."
        )
    }
    
    private func analyzeWilliamsR(candles: [Candle]) -> Signal? {
        guard let wr = calculateWilliamsR(candles: candles) else { return nil }
        
        var action: SignalAction = .hold
        var reason = "Williams %R nötr."
        
        if wr < -80 { action = .buy; reason = "%R < -80 (Aşırı Satım)." }
        else if wr > -20 { action = .sell; reason = "%R > -20 (Aşırı Alım)." }
        
        return Signal(
            strategyName: "Williams %R",
            action: action,
            confidence: 75,
            reason: reason,
            indicatorValues: ["%R": String(format: "%.1f", wr)],
            logic: "Kapanışın tepe/dip aralığındaki yerini ölçer.",
            successContext: "Hızlı hareket eden piyasalarda dönüşleri yakalar.",
            simplifiedExplanation: "Williams %R, fiyatın tepeye mi yoksa dibe mi daha yakın olduğunu söyler. Değerler her zaman negatiftir (0 ile -100 arası).\n\n• -80 ile -100 arası: Fiyat diplerde, alım fırsatı olabilir.\n• 0 ile -20 arası: Fiyat tepelerde, satış fırsatı olabilir."
        )
    }
    
    // MARK: - Math Calculations
    
    // MARK: - Math Calculations
    
    // MARK: - Math Calculations
    
    internal func calculateRSIValue(candles: [Candle]) -> Double {
        let period = 14
        let prices = candles.map { $0.close }
        guard prices.count > period else { return 50.0 }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<prices.count {
            let diff = prices[i] - prices[i-1]
            gains.append(max(diff, 0))
            losses.append(max(-diff, 0))
        }
        
        let avgGain = gains.suffix(period).reduce(0, +) / Double(period)
        let avgLoss = losses.suffix(period).reduce(0, +) / Double(period)
        
        if avgLoss == 0 { return 100.0 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    internal func calculateSMAValues(candles: [Candle]) -> (Double?, Double?) {
        let prices = candles.map { $0.close }
        guard prices.count >= 50 else { return (nil, nil) }
        return (prices.suffix(20).reduce(0, +)/20.0, prices.suffix(50).reduce(0, +)/50.0)
    }
    
    internal func calculateBollingerValues(candles: [Candle]) -> (Double?, Double?) {
        let period = 20
        let prices = candles.map { $0.close }
        guard prices.count >= period else { return (nil, nil) }
        
        let slice = prices.suffix(period)
        let sma = slice.reduce(0, +) / Double(period)
        let sumSquaredDiff = slice.map { pow($0 - sma, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(period))
        
        return (sma + 2*stdDev, sma - 2*stdDev)
    }
    
    internal func calculateMACD(candles: [Candle]) -> (Double?, Double?, Double?) {
        let prices = candles.map { $0.close }
        guard prices.count >= 26 else { return (nil, nil, nil) }
        
        // EMA 12
        let ema12 = calculateEMA(prices: prices, period: 12)
        // EMA 26
        let ema26 = calculateEMA(prices: prices, period: 26)
        
        guard let e12 = ema12, let e26 = ema26 else { return (nil, nil, nil) }
        
        let macdLine = e12 - e26
        
        // Signal Line (9-day EMA of MACD Line)
        // Note: For strict accuracy, we'd need a history of MACD values. 
        // Here we approximate by calculating MACD for the last 9 points.
        // For V7, we will use a simplified Signal Line calculation:
        // let signalLine = macd.signale * 0.8 // Simplified for performance without full history
        let signalLine = macdLine * 0.8 // Simplified for performance without full history
        let histogram = macdLine - signalLine
        
        return (macdLine, signalLine, histogram)
    }
    
    private func calculateStochastic(candles: [Candle]) -> (Double?, Double?) {
        let period = 14
        guard candles.count >= period else { return (nil, nil) }
        
        let slice = candles.suffix(period)
        let low = slice.map { $0.low }.min() ?? 0
        let high = slice.map { $0.high }.max() ?? 1
        let close = slice.last?.close ?? 0
        
        let k = ((close - low) / (high - low)) * 100
        let d = k // Simplified %D
        
        return (k, d)
    }
    
    private func calculateCCI(candles: [Candle]) -> Double? {
        let period = 20
        guard candles.count >= period else { return nil }
        
        let slice = candles.suffix(period)
        let tp = slice.map { ($0.high + $0.low + $0.close) / 3.0 }
        let smaTP = tp.reduce(0, +) / Double(period)
        
        // Mean Deviation
        let md = tp.map { abs($0 - smaTP) }.reduce(0, +) / Double(period)
        
        guard md != 0 else { return 0 }
        let lastTP = tp.last ?? 0
        return (lastTP - smaTP) / (0.015 * md)
    }
    
    private func calculateADX(candles: [Candle]) -> Double? {
        // Real ADX Calculation (Simplified TR and DM)
        let period = 14
        guard candles.count > period + 1 else { return nil }
        
        // 1. Calculate True Range (TR) and Directional Movement (+DM, -DM)
        var trSum: Double = 0
        var plusDMSum: Double = 0
        var minusDMSum: Double = 0
        
        for i in (candles.count - period)..<candles.count {
            let current = candles[i]
            let prev = candles[i-1]
            
            let tr = max(current.high - current.low, max(abs(current.high - prev.close), abs(current.low - prev.close)))
            let upMove = current.high - prev.high
            let downMove = prev.low - current.low
            
            let plusDM = (upMove > downMove && upMove > 0) ? upMove : 0
            let minusDM = (downMove > upMove && downMove > 0) ? downMove : 0
            
            trSum += tr
            plusDMSum += plusDM
            minusDMSum += minusDM
        }
        
        if trSum == 0 { return 0 }
        
        let plusDI = 100 * (plusDMSum / trSum)
        let minusDI = 100 * (minusDMSum / trSum)
        
        let dx = (abs(plusDI - minusDI) / (plusDI + minusDI)) * 100
        return dx // Using DX as ADX approximation for single point
    }
    
    private func calculateWilliamsR(candles: [Candle]) -> Double? {
        let period = 14
        guard candles.count >= period else { return nil }
        
        let slice = candles.suffix(period)
        let highestHigh = slice.map { $0.high }.max() ?? 1
        let lowestLow = slice.map { $0.low }.min() ?? 0
        let close = slice.last?.close ?? 0
        
        return ((highestHigh - close) / (highestHigh - lowestLow)) * -100
    }
    
    // Helper: Exponential Moving Average
    private func calculateEMA(prices: [Double], period: Int) -> Double? {
        guard prices.count >= period else { return nil }
        
        let k = 2.0 / Double(period + 1)
        var ema = prices.prefix(period).reduce(0, +) / Double(period) // Start with SMA
        
        for price in prices.dropFirst(period) {
            ema = (price * k) + (ema * (1 - k))
        }
        
        return ema
    }
}
