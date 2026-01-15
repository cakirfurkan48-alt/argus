import SwiftUI

// MARK: - EXTENSIONS FOR COMPATIBILITY
extension OrionScoreResult {
    var patternName: String? {
        if components.patternDesc.isEmpty || components.patternDesc == "Formasyon Yok" { return nil }
        return components.patternDesc
    }
}

// MARK: - PREMIUM ORION COCKPIT VIEW
struct OrionDetailView: View {
    let symbol: String
    let orion: OrionScoreResult
    let candles: [Candle]?
    let patterns: [OrionChartPattern]? // Orion V3 Patterns
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isProfessorMode = false // 🎓 Professor Mode State
    
    var body: some View {
        ZStack { // Main ZStack for Overlay
            VStack(spacing: 0) {
                
                // MARK: 1. COMPACT HEADER (Sticky Top)
                HStack(alignment: .center) {
                    // Symbol + Title
                    VStack(alignment: .leading, spacing: 2) {
                        Text(symbol)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Orion Teknik Analiz")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Professor Mode Toggle
                    Button(action: {
                        withAnimation(.spring()) {
                            isProfessorMode.toggle()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isProfessorMode ? Theme.tint : Theme.secondaryBackground)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isProfessorMode ? .white : Theme.tint)
                        }
                    }
                    .padding(.trailing, 8)
                    
                    // Score Badge (Compact)
                    HStack(spacing: 12) {
                        // Score
                        HStack(spacing: 2) {
                            Text("\(Int(orion.score))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(colorForScore(orion.score))
                            
                            Text("/ 100")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .offset(y: 4)
                        }
                        
                        // Verdict Logic
                        Text(getVerdictSummary(score: orion.score))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colorForScore(orion.score))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .background(Theme.background) // Sticky feel
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: 1.5 PATTERN ALERT CARD
                        if let patterns = patterns, let pattern = patterns.max(by: { $0.confidence < $1.confidence }) {
                            PatternAlertCard(pattern: pattern)
                                .padding(.horizontal, 16)
                        }
                        
                        // MARK: 2. COCKPIT GRID (2x2) - Screen Center
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            
                            // A. MOMENTUM (RSI + Stochastic)
                            FlipCard(
                                front: {
                                    CockpitCardContent(title: "Momentum", icon: "speedometer", color: .orange) {
                                        VStack(spacing: 8) {
                                            RSIGauge(value: orion.components.momentum * 4)
                                                .scaleEffect(0.9)
                                                .frame(height: 50)
                                            Text(getMomentumState(orion.components.momentum))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                },
                                back: {
                                    EducationalCardContent(
                                        title: "Momentum Nedir?",
                                        text: getMomentumEducation(orion.components.momentum),
                                        color: .orange
                                    )
                                }
                            )
                            
                            // B. MARKET STRUCTURE (Price Map)
                            FlipCard(
                                front: {
                                    CockpitCardContent(title: "Piyasa Yapısı", icon: "building.columns.fill", color: .blue) {
                                        VStack(spacing: 12) {
                                            if let candles = candles, let last = candles.last {
                                                let range = (candles.map { $0.high }.max() ?? last.high) - (candles.map { $0.low }.min() ?? last.low)
                                                let sup = last.low - (range * 0.2)
                                                let res = last.high + (range * 0.2)
                                                
                                                PriceLevelMap(currentPrice: last.close, support: sup, resistance: res)
                                                
                                                Text(getStructureState(current: last.close, support: sup, resistance: res))
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(Theme.textSecondary)
                                            } else {
                                                Text("Veri Yok").font(.caption).foregroundColor(.gray)
                                            }
                                        }
                                    }
                                },
                                back: {
                                    EducationalCardContent(
                                        title: "Yapı Analizi",
                                        text: "Fiyatın destek (ucuz) ve direnç (pahalı) bölgelerine yakınlığını ölçer. İbre sağa (R) yakınsa satış, sola (S) yakınsa tepki beklenebilir.",
                                        color: .blue
                                    )
                                }
                            )
                            
                            // C. PATTERN (Context Chart)
                            FlipCard(
                                front: {
                                    CockpitCardContent(title: "Formasyon", icon: "eye.fill", color: .pink) {
                                         VStack(spacing: 8) {
                                            if let candles = candles, !candles.isEmpty {
                                                PatternContextChart(candles: Array(candles.suffix(15)))
                                                    .frame(height: 40)
                                            } else {
                                                Text("Grafik Yok").font(.caption2).foregroundColor(.gray)
                                            }
                                            
                                            Text(orion.patternName ?? "Formasyon Yok")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                    }
                                },
                                back: {
                                    EducationalCardContent(
                                        title: orion.patternName ?? "Formasyon",
                                        text: getPatternEducation(name: orion.patternName),
                                        color: .pink
                                    )
                                }
                            )
                            
                            // D. TREND (Compass)
                            FlipCard(
                                front: {
                                    CockpitCardContent(title: "Trend", icon: "chart.line.uptrend.xyaxis", color: .purple) {
                                        VStack(spacing: 8) {
                                            let adxSim = orion.components.trend / 25.0 * 50.0 
                                            TrendCompass(trendScore: orion.components.trend, adx: adxSim)
                                        }
                                    }
                                },
                                back: {
                                    EducationalCardContent(
                                        title: "Trend Yönü",
                                        text: getTrendEducation(score: orion.components.trend),
                                        color: .purple
                                    )
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // MARK: 2.5. CHIMERA İÇGÖRÜ (DNA Özeti)
                        ChimeraInsightCard(symbol: symbol, orion: orion)
                            .padding(.horizontal, 16)
                        
                        // MARK: 3. TACTICAL FEEDBACK
                        HStack(spacing: 12) {
                             Image(systemName: "hand.tap.fill")
                                .font(.title2)
                                .foregroundColor(.gray.opacity(0.5))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("İpucu")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                Text("Kartların üzerine dokunarak detaylı açıklamalarını okuyabilirsin.")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Theme.secondaryBackground.opacity(0.5))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .blur(radius: isProfessorMode ? 10 : 0) // Blur content when Professor is active
            
            // MARK: PROFESSOR OVERLAY
            if isProfessorMode {
                ProfessorOverlay(isPresented: $isProfessorMode)
            }
        }
    }
}

struct ProfessorOverlay: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }
            
            ScrollView {
                VStack(spacing: 40) {
                    
                    // Header Intro
                    HStack {
                        Text("🎓 Profesör Modu")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, 60)
                    .padding(.horizontal)
                    
                    // 1. Momentum Explanation (Top Left)
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Momentum (Hız)")
                                .font(.headline.bold())
                                .foregroundColor(.orange)
                            Text("Fiyatın ne kadar 'agresif' hareket ettiğini ölçer. Aşırı hızlanma (top left) genelde bir geri çekilme (kaza) habercisidir. Düşük hız güvenli ama yavaş kazanç demektir.")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .frame(maxWidth: 200)
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    
                    // 2. Structure Explanation (Top Right)
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("Piyasa Yapısı")
                                .font(.headline.bold())
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.trailing)
                            Text("Fiyat okyanusundaki 'Ada' (Destek) ve 'Kayalık' (Direnç) bölgelerini gösterir. Fiyat kayalıklara (R) yaklaştıysa çarpmamak için dümeni kırmak gerekebilir.")
                                .font(.caption)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .frame(maxWidth: 200)
                    }
                    .padding(.trailing, 20)
                    
                    // 3. Pattern Explanation (Bottom Left)
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Formasyonlar")
                                .font(.headline.bold())
                                .foregroundColor(.pink)
                            Text("Piyasanın bıraktığı ayak izleridir. 'Doji' gibi izler kararsızlığı, 'Hammer' gibi izler ise dönüşü müjdeler. Dedektif gibi iz süreriz.")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .frame(maxWidth: 200)
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    
                    // 4. Trend Explanation (Bottom Right)
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("Trend (Rüzgar)")
                                .font(.headline.bold())
                                .foregroundColor(.purple)
                                .multilineTextAlignment(.trailing)
                            Text("Rüzgarın arkandan esip esmediğini söyler. Rüzgara karşı işeme (Counter-Trend), ıslanırsın. Trend senin dostundur.")
                                .font(.caption)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .frame(maxWidth: 200)
                    }
                    .padding(.trailing, 20)
                    
                    Spacer()
                    Text("Kapatmak için dokun")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom)
                }
            }
        }
        .transition(.opacity)
    }
}

// MARK: - FLIP CARD COMPONENT
struct FlipCard<Front: View, Back: View>: View {
    let front: () -> Front
    let back: () -> Back
    
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            front()
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            back()
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                isFlipped.toggle()
            }
        }
    }
}

struct EducationalCardContent: View {
    let title: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
            
            Spacer()
        }
        .padding(12)
        .frame(height: 100) // Fixed height to match front
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct CockpitCardContent<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                    .padding(6)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Flip Hint
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            // Content
            content()
                .frame(height: 60)
        }
        .padding(12)
        .frame(height: 100) // Fixed height
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - HELPER EXTENSION UDPATE
extension OrionDetailView {
    private func getMomentumEducation(_ score: Double) -> String {
        if score > 20 { return "Fiyat çok hızlı yükseldi (Aşırı Alım). Kâr satışı gelebilir, dikkatli ol." }
        if score > 15 { return "Alıcılar hala güçlü. Trend yukarı yönlü devam ediyor." }
        if score > 5 { return "Piyasa kararsız veya hafif satıcılı. Belirgin bir momentum yok." }
        return "Fiyat aşırı düştü (Aşırı Satım). Tepki alımı veya dönüş sinyali yakındır."
    }
    
    private func getTrendEducation(score: Double) -> String {
        if score > 15 { return "Güçlü bir Yükseliş Trendi var. 'Trend senin dostundur', pozisyon korunabilir." }
        if score > 10 { return "Trend zayıflıyor veya yatay bir banda girdi. Testere piyasası olabilir." }
        return "Düşüş Trendi hakim veya trend yok. Alım için acele etme, destek bekle."
    }
    
    private func getPatternEducation(name: String?) -> String {
        guard let name = name else { return "Henüz belirgin bir mum formasyonu oluşmadı." }
        if name.contains("Doji") { return "Kararsızlık sinyali. Boğalar ve ayılar yenişemedi. Bir sonraki mum yönü tayin edecek." }
        if name.contains("Hammer") { return "Düşüşün sonuna gelmiş olabiliriz. Ayılar fiyatı düşürdü ama boğalar geri topladı ( Dönüş Sinyali)." }
        if name.contains("Engulfing") { return "Yutulan Mum. Önceki mumu tamamen içine alan güçlü bir hareket. Yön değişimi habercisidir." }
        if name.contains("Star") { return "Zirvede görülen dönüş sinyali. Yükseliş yorulmuş olabilir." }
        return "Özel bir mum dizilimi tespit edildi. Fiyat hareketlerini yakından izle."
    }

    private func getMomentumState(_ score: Double) -> String {
        if score > 20 { return "Aşırı Alım" }
        if score > 15 { return "Pozitif" }
        if score > 10 { return "Nötr" }
        if score > 5 { return "Negatif" }
        return "Aşırı Satım"
    }
    
    private func getStructureState(current: Double, support: Double, resistance: Double) -> String {
        let range = resistance - support
        if range == 0 { return "Nötr" }
        let position = (current - support) / range
        if position > 0.8 { return "Dirence Yakın" }
        if position < 0.2 { return "Desteğe Yakın" }
        return "Kanal İçi"
    }

    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 75...100: return Theme.positive
        case 50..<75: return .yellow
        default: return Theme.negative
        }
    }
    
    private func getVerdictSummary(score: Double) -> String {
        if score >= 75 { return "GÜÇLÜ AL" }
        if score >= 60 { return "AL" }
        if score >= 40 { return "TUT" }
        return "SAT"
    }
}


// MARK: - Pattern Logic Chart
struct PatternContextChart: View {
    let candles: [Candle]
    
    var body: some View {
        GeometryReader { geo in
            let closePrices = candles.map { $0.close }
            let minPrice = candles.map { $0.low }.min() ?? 0
            let maxPrice = candles.map { $0.high }.max() ?? 1
            let range = maxPrice - minPrice
            
            let width = geo.size.width
            let height = geo.size.height
            let stepX = width / CGFloat(max(1, candles.count - 1))
            
            ZStack {
                // Candles
                ForEach(Array(candles.enumerated()), id: \.offset) { index, candle in
                    let x = CGFloat(index) * stepX
                    
                    // Wick
                    let yHigh = height - ((candle.high - minPrice) / range * height)
                    let yLow = height - ((candle.low - minPrice) / range * height)
                    
                    // Body
                    let open = height - ((candle.open - minPrice) / range * height)
                    let close = height - ((candle.close - minPrice) / range * height)
                    
                    let isGreen = candle.close >= candle.open
                    let color = isGreen ? Theme.positive : Theme.negative
                    
                    // Wick Line
                    Path { path in
                        path.move(to: CGPoint(x: x, y: yHigh))
                        path.addLine(to: CGPoint(x: x, y: yLow))
                    }
                    .stroke(color, lineWidth: 1)
                    
                    // Body Rect
                    Path { path in
                        let yTop = min(open, close)
                        let yBottom = max(open, close)
                        let h = max(1, yBottom - yTop)
                        
                        path.addRect(CGRect(x: x - 2, y: yTop, width: 4, height: h))
                    }
                    .fill(color)
                    
                    // Highlight Last Candle (The Pattern Signal)
                    if index == candles.count - 1 {
                        // 1. Selection Box
                        Path { path in
                            let yTop = min(open, close) - 4
                            let yBottom = max(open, close) + 4
                            let xLeft = x - 6
                            let rect = CGRect(x: xLeft, y: yTop, width: 12, height: (yBottom - yTop))
                            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
                        }
                        .stroke(Theme.tint, style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2]))
                        
                        // 2. Indicator Arrow (Below candle)
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.tint)
                            .position(x: x, y: yLow + 8)
                            .shadow(color: Theme.tint.opacity(0.5), radius: 2)
                    }
                }
            }
        }
    }
}

struct PriceLevelMap: View {
    let currentPrice: Double
    let support: Double
    let resistance: Double
    
    var progress: Double {
        let range = resistance - support
        guard range > 0 else { return 0.5 }
        let value = currentPrice - support
        return min(1.0, max(0.0, value / range))
    }
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.positive.opacity(0.4), Theme.negative.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 4)
                        .offset(y: 4)
                    
                    // Ball
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .white.opacity(0.6), radius: 4)
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.5))
                        .offset(x: (geo.size.width - 8) * progress, y: 2)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("S")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Theme.positive)
                Spacer()
                Text("R")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Theme.negative)
            }
        }
        .padding(8)
        //.background(Color.black.opacity(0.3)) // Removed background for cleaner look inside card
        .cornerRadius(8)
    }
}


struct TrendCompass: View {
    let trendScore: Double
    let adx: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                .frame(width: 40, height: 40)
            
            Image(systemName: "arrow.up")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(trendScore > 12.5 ? Theme.positive : Theme.negative)
                .rotationEffect(.degrees(trendScore > 12.5 ? 0 : 180))
                .shadow(color: (trendScore > 12.5 ? Theme.positive : Theme.negative).opacity(0.5), radius: 5)
            
            // ADX Strength Ring
            Circle()
                .trim(from: 0, to: min(1.0, adx / 50.0)) // 50 ADX = Full Circle
                .stroke(Theme.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 40)
        }
    }
}

struct RSIGauge: View {
    let value: Double // 0-100
    
    var body: some View {
        ZStack {
            // 1. Arc Background (Yarım Daire)
            Circle()
                .trim(from: 0.0, to: 0.5)
                .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(180))
                .frame(width: 80, height: 80)
            
            // 2. Colored Arc (Gradient)
            Circle()
                .trim(from: 0.0, to: 0.5)
                .stroke(
                    LinearGradient(
                        colors: [.green, .yellow, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(180))
                .frame(width: 80, height: 80)
            
            // 3. Labels (30 - 70)
            HStack {
                Text("30").font(.system(size: 8)).foregroundColor(.gray).offset(x: 5, y: -5)
                Spacer()
                Text("70").font(.system(size: 8)).foregroundColor(.gray).offset(x: -5, y: -5)
            }
            .frame(width: 80)
            .offset(y: 10)
            
            // 4. Needle (İbre)
            // Value 0-100 mapped to -90 to +90 degrees
            let angle = (min(max(value, 0), 100) / 100.0) * 180.0 - 90.0
            
            ZStack {
                // İbre ucu
                Capsule()
                    .fill(Color.white)
                    .frame(width: 3, height: 30)
                    .offset(y: -15) // Pivot center adjustment
                
                // Pivot noktası
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
            .rotationEffect(.degrees(angle))
            .offset(y: 5) // Arc center alignment
            
            // 5. Value Text
            VStack {
                Spacer()
                Text("RSI \(Int(value))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(value > 70 ? .red : (value < 30 ? .green : .white))
                    .offset(y: 10) // Push below arc
            }
            .frame(height: 50)
        }
        .frame(height: 50) // Container height constraint (half circle)
        .offset(y: 10) // Visual center adjustment
    }
}

struct InfoButton: View {
    let title: String
    let text: String
    @State private var showInfo = false
    
    var body: some View {
        Button(action: { showInfo.toggle() }) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .alert(isPresented: $showInfo) {
            Alert(title: Text(title), message: Text(text), dismissButton: .default(Text("Tamam")))
        }
    }
}

// MARK: - PATTERN ALERT CARD
struct PatternAlertCard: View {
    let pattern: OrionChartPattern
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Block
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(pattern.type.isBullish ? Theme.positive.opacity(0.1) : Theme.negative.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: pattern.type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(pattern.type.isBullish ? Theme.positive : Theme.negative)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pattern.type.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(Int(pattern.confidence))% Güven")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white.opacity(0.8))
                        .cornerRadius(4)
                }
                
                if let target = pattern.targetPrice {
                    HStack(spacing: 4) {
                        Text("Hedef:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f", target))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(pattern.type.isBullish ? Theme.positive : Theme.negative)
                            .monospacedDigit()
                    }
                }
                
                Text(pattern.description)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(pattern.type.isBullish ? Theme.positive.opacity(0.3) : Theme.negative.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - CHIMERA İÇGÖRÜ KARTI
struct ChimeraInsightCard: View {
    let symbol: String
    let orion: OrionScoreResult
    
    private var chimeraResult: ChimeraFusionResult {
        let regime = ChironRegimeEngine.shared.globalResult.regime
        
        return ChimeraSynergyEngine.shared.fuse(
            symbol: symbol,
            orion: orion,
            hermesImpactScore: nil, // Orion kartında Hermes yok
            titanScore: nil, // Atlas verisi de yok
            currentPrice: 0,
            marketRegime: regime
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "dna")
                    .font(.caption)
                    .foregroundColor(.cyan)
                
                Text("CHIMERA DNA")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Spacer()
                
                // Sürücü Badge
                Text(chimeraResult.primaryDriver)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(6)
            }
            
            // DNA Bar'ları
            VStack(spacing: 8) {
                DNABar(label: "MOM", value: chimeraResult.dna.momentum, color: .orange)
                DNABar(label: "TREND", value: chimeraResult.dna.trend, color: .purple)
                DNABar(label: "YAPI", value: chimeraResult.dna.structure, color: .blue)
            }
            
            // Sinyal (varsa)
            if let signal = chimeraResult.signals.first {
                HStack(spacing: 8) {
                    Circle()
                        .fill(signal.severity > 0.7 ? Color.red : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(signal.title)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(signal.severity > 0.7 ? .red : .orange)
                    
                    Spacer()
                    
                    Text(signal.description)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - DNA Bar Component
struct DNABar: View {
    let label: String
    let value: Double // 0-100
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 45, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Fill
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * (value / 100.0), height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(value))")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 25, alignment: .trailing)
        }
    }
}

