import SwiftUI
import Charts

// MARK: - Orion Module Detail View
struct OrionModuleDetailView: View {
    let type: CircuitNode
    let symbol: String
    let analysis: OrionScoreResult
    let candles: [Candle]
    let onClose: () -> Void
    
    // Theme Constants matching the User's Dark Mode Image
    private let darkBg = Color(red: 0.02, green: 0.02, blue: 0.04)
    private let cardBg = Color(red: 0.05, green: 0.05, blue: 0.08)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let orange = Color(red: 1.0, green: 0.6, blue: 0.0)
    
    var body: some View {
        ZStack {
            // Background
            darkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Live Analysis Text
                        liveAnalysisCard
                        
                        // 2. Section Title
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(cyan)
                            Text("Teknik Göstergeler")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // 3. Indicator Charts
                        if type == .trend {
                            technicalCard(title: "GÖRECELİ GÜÇ ENDEKSİ", subtitle: "RSI (14)", value: "68.4", delta: "+2.4% (24s)") {
                                rsiChart
                            }
                            
                            technicalCard(title: "PRICE ACTION", subtitle: "Hareketli Ortalamalar", value: String(format: "%.2f", candles.last?.close ?? 0), delta: "+5.1% (30g)") {
                                maChart
                            }
                        } else if type == .momentum {
                             technicalCard(title: "MACD", subtitle: "Momentum Convergence", value: "Bullish", delta: "Strong") {
                                rsiChart // Reusing chart style for demo
                            }
                        } else {
                            // Volume / Structure
                            technicalCard(title: "VOLUME PROFILE", subtitle: "OBV & Flow", value: "High", delta: "+12%") {
                                maChart // Reusing chart style for demo
                            }
                        }
                        
                        // 4. Learning Section
                        learningSection
                        
                        // Spacer for bottom bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.vertical)
                }
            }
            
            // Bottom Action Bar
            VStack {
                Spacer()
                bottomActionBar
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(cyan)
            }
            
            Spacer()
            
            Text("\(type.title) DETAY ANALİZİ")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(1)
            
            Spacer()
            
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(cyan)
        }
        .padding()
        .background(cardBg.opacity(0.8))
    }
    
    private var liveAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(cyan).frame(width: 8, height: 8)
                Text("LIVE ANALYSIS")
                    .font(.caption)
                    .foregroundColor(cyan)
                    .bold()
                Spacer()
            }
            
            // Rich Text Construction
            Group {
                Text("Trend şu an güçlü bir ")
                    .foregroundColor(.gray) +
                Text("yükseliş eğiliminde (Bullish)")
                    .foregroundColor(cyan)
                    .bold() +
                Text(". RSI ve Hareketli Ortalama verileri ")
                    .foregroundColor(.gray) +
                Text("pozitif ivmeyi")
                    .foregroundColor(.white)
                    .bold() +
                Text(" destekliyor. Direnç seviyesi üzerinde kalıcılık bekleniyor.")
                    .foregroundColor(.gray)
            }
            .font(.system(size: 15, design: .monospaced))
            .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .background(cardBg)
        )
        .padding(.horizontal)
    }
    
    private func technicalCard<Content: View>(title: String, subtitle: String, value: String, delta: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(cyan)
                    Text(subtitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(delta)
                        .font(.caption)
                        .foregroundColor(cyan)
                }
            }
            
            // Chart Content
            content()
                .frame(height: 120)
            
            // X-Axis Labels (Mock)
            HStack {
                Text("00:00").font(.caption2).foregroundColor(.gray)
                Spacer()
                Text("12:00").font(.caption2).foregroundColor(.gray)
                Spacer()
                Text("24:00").font(.caption2).foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .background(cardBg)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Charts (Simplified using SwiftUI Path or Charts)
    
    private var rsiChart: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                
                // Mock Sine Wave
                path.move(to: CGPoint(x: 0, y: height * 0.8))
                for x in stride(from: 0, to: width, by: 5) {
                    let relativeX = x / width
                    let y = height * 0.5 + sin(relativeX * 10) * (height * 0.3)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
    
    private var maChart: some View {
        GeometryReader { geo in
            ZStack {
                // MA 1 (Cyan)
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.7))
                    for x in stride(from: 0, to: width, by: 5) {
                        let relativeX = x / width
                        let y = height * 0.6 + sin(relativeX * 8) * (height * 0.2)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                
                // MA 2 (Orange)
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.8))
                    for x in stride(from: 0, to: width, by: 5) {
                        let relativeX = x / width
                        let y = height * 0.7 + cos(relativeX * 6) * (height * 0.15)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
    }
    
    // MARK: - Learning Section
    
    private var learningSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(
                content: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Yükseliş Trendi (Bull Market)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Fiyatların birbirini izleyen daha yüksek zirveler ve daha yüksek dipler oluşturması durumudur. Yatırımcı güveninin yüksek olduğunu gösterir.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(nil)
                            }
                        }
                        .padding(.top, 8)
                        
                        HStack(alignment: .top) {
                            Image(systemName: "info.circle.fill")
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Neden Önemlidir?")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Trend yönünü belirlemek, dalgalara karşı değil, dalgalarla birlikte hareket etmenizi sağlar. 'Trend is your friend' (Trend dostunuzdur) temel bir finans prensibidir.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {}) {
                            Text("TÜM MODÜLÜ İNCELE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(cyan)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(cyan.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                },
                label: {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(orange)
                        Text("Öğren: Trend Nedir?")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            )
            .accentColor(.white)
        }
        .background(cardBg)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("ALARM KUR")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(cyan)
                .cornerRadius(12)
            }
            
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(darkBg.opacity(0.95))
    }
}
