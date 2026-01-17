import SwiftUI

// MARK: - ORION MOTHERBOARD VIEW (Full-Screen Circuit Board)
// Professional Terminal Design - No Emojis, Educational, Interactive

struct OrionMotherboardView: View {
    let analysis: MultiTimeframeAnalysis
    let symbol: String
    
    @State private var selectedTimeframe: TimeframeMode = .daily
    @State private var selectedNode: CircuitNode? = nil
    @State private var flowPhase: CGFloat = 0
    
    // Theme
    private let boardColor = Color(red: 0.02, green: 0.02, blue: 0.06)
    private let traceColor = Color(red: 0.1, green: 0.1, blue: 0.15)
    private let activeGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let activeRed = Color(red: 0.9, green: 0.2, blue: 0.2)
    private let neutralGray = Color(red: 0.3, green: 0.3, blue: 0.35)
    private let accentCyan = Color(red: 0.0, green: 0.8, blue: 0.9)
    
    var currentOrion: OrionScoreResult {
        selectedTimeframe == .daily ? analysis.daily : analysis.intraday
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // LAYER 1: Circuit Board Background
                boardBackground
                
                // LAYER 2: Circuit Traces (Wires)
                circuitTraces(in: geo.size)
                
                // LAYER 3: Data Flow Animation
                dataFlowParticles(in: geo.size)
                
                // LAYER 4: Nodes (Interactive Components)
                VStack(spacing: 0) {
                    // Header: Symbol + Timeframe Selector
                    headerBar
                    
                    Spacer()
                    
                    // Main Circuit Layout
                    HStack(spacing: 0) {
                        // LEFT: Input Stations
                        inputStations(in: geo.size)
                        
                        Spacer()
                        
                        // CENTER: CPU (Consensus Engine)
                        cpuNode(in: geo.size)
                        
                        Spacer()
                        
                        // RIGHT: Output (Price Verdict)
                        outputNode(in: geo.size)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Footer: Strategic Advice
                    strategicAdviceBar
                }
                
                // LAYER 5: Detail Panel (Overlaid when node selected)
                if let node = selectedNode {
                    nodeDetailPanel(for: node)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                flowPhase = 1
            }
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ORION ANALYSIS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(2)
                Text(symbol)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Timeframe Selector
            HStack(spacing: 0) {
                timeframeButton(.intraday, label: "4H")
                timeframeButton(.daily, label: "1D")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private func timeframeButton(_ mode: TimeframeMode, label: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeframe = mode
            }
        }) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(selectedTimeframe == mode ? .black : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedTimeframe == mode ? accentCyan : Color.clear)
        }
    }
    
    // MARK: - Board Background
    private var boardBackground: some View {
        ZStack {
            boardColor.ignoresSafeArea()
            
            // Grid Pattern (Subtle)
            Canvas { context, size in
                let gridSpacing: CGFloat = 20
                for x in stride(from: 0, to: size.width, by: gridSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(traceColor), lineWidth: 0.5)
                }
                for y in stride(from: 0, to: size.height, by: gridSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(traceColor), lineWidth: 0.5)
                }
            }
        }
    }
    
    // MARK: - Circuit Traces
    private func circuitTraces(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let centerY = canvasSize.height / 2
            let leftX: CGFloat = 100
            let cpuX = canvasSize.width / 2
            let rightX = canvasSize.width - 80
            
            // Trace: Trend -> CPU
            drawTrace(context: context, from: CGPoint(x: leftX, y: centerY - 80), to: CGPoint(x: cpuX - 50, y: centerY), status: getTrendStatus())
            
            // Trace: Momentum -> CPU
            drawTrace(context: context, from: CGPoint(x: leftX, y: centerY), to: CGPoint(x: cpuX - 50, y: centerY), status: getMomentumStatus())
            
            // Trace: Volume -> CPU
            drawTrace(context: context, from: CGPoint(x: leftX, y: centerY + 80), to: CGPoint(x: cpuX - 50, y: centerY), status: getVolumeStatus())
            
            // Trace: CPU -> Output
            drawTrace(context: context, from: CGPoint(x: cpuX + 50, y: centerY), to: CGPoint(x: rightX, y: centerY), status: getOverallStatus())
        }
    }
    
    private func drawTrace(context: GraphicsContext, from: CGPoint, to: CGPoint, status: SignalStatus) {
        var path = Path()
        path.move(to: from)
        
        // Create L-shaped trace (circuit style)
        let midX = (from.x + to.x) / 2
        path.addLine(to: CGPoint(x: midX, y: from.y))
        path.addLine(to: CGPoint(x: midX, y: to.y))
        path.addLine(to: to)
        
        let color: Color = {
            switch status {
            case .positive: return activeGreen
            case .negative: return activeRed
            case .neutral: return neutralGray
            }
        }()
        
        context.stroke(path, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Data Flow Particles
    private func dataFlowParticles(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let centerY = canvasSize.height / 2
            let leftX: CGFloat = 100
            let cpuX = canvasSize.width / 2
            
            // Animated particles along traces
            let particlePositions: [(CGPoint, SignalStatus)] = [
                (CGPoint(x: leftX + (cpuX - leftX) * flowPhase, y: centerY - 80 + 80 * flowPhase), getTrendStatus()),
                (CGPoint(x: leftX + (cpuX - leftX) * ((flowPhase + 0.3).truncatingRemainder(dividingBy: 1)), y: centerY), getMomentumStatus()),
                (CGPoint(x: leftX + (cpuX - leftX) * ((flowPhase + 0.6).truncatingRemainder(dividingBy: 1)), y: centerY + 80 - 80 * flowPhase), getVolumeStatus())
            ]
            
            for (pos, status) in particlePositions {
                let color: Color = {
                    switch status {
                    case .positive: return activeGreen
                    case .negative: return activeRed
                    case .neutral: return neutralGray
                    }
                }()
                
                let rect = CGRect(x: pos.x - 4, y: pos.y - 4, width: 8, height: 8)
                context.fill(Circle().path(in: rect), with: .color(color))
                
                // Glow
                let glowRect = CGRect(x: pos.x - 8, y: pos.y - 8, width: 16, height: 16)
                context.fill(Circle().path(in: glowRect), with: .color(color.opacity(0.3)))
            }
        }
    }
    
    // MARK: - Input Stations
    private func inputStations(in size: CGSize) -> some View {
        VStack(spacing: 24) {
            stationNode(
                node: .trend,
                title: "TREND",
                value: String(format: "%.0f", currentOrion.components.trend),
                maxValue: 25,
                icon: "chart.line.uptrend.xyaxis",
                status: getTrendStatus()
            )
            
            stationNode(
                node: .momentum,
                title: "MOMENTUM",
                value: String(format: "%.0f", currentOrion.components.momentum),
                maxValue: 25,
                icon: "speedometer",
                status: getMomentumStatus()
            )
            
            stationNode(
                node: .volume,
                title: "VOLUME",
                value: String(format: "%.0f", currentOrion.components.structure),
                maxValue: 35,
                icon: "chart.bar.fill",
                status: getVolumeStatus()
            )
        }
    }
    
    private func stationNode(node: CircuitNode, title: String, value: String, maxValue: Double, icon: String, status: SignalStatus) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedNode = selectedNode == node ? nil : node
            }
        }) {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(statusColor(status))
                
                // Title
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                // Value
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                // Mini Progress
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(statusColor(status))
                            .frame(width: geo.size.width * min((Double(value) ?? 0) / maxValue, 1.0))
                    }
                }
                .frame(width: 60, height: 4)
            }
            .frame(width: 80, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(statusColor(status).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - CPU Node
    private func cpuNode(in size: CGSize) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedNode = selectedNode == .cpu ? nil : .cpu
            }
        }) {
            VStack(spacing: 8) {
                Text("KONSENSUS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                ZStack {
                    // Outer Ring
                    Circle()
                        .stroke(accentCyan.opacity(0.3), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    // Progress Ring
                    Circle()
                        .trim(from: 0, to: currentOrion.score / 100)
                        .stroke(accentCyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    // Inner Chip
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 70, height: 70)
                        .overlay(
                            VStack(spacing: 2) {
                                Text(String(format: "%.0f", currentOrion.score))
                                    .font(.system(size: 28, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(getVerdictText())
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(statusColor(getOverallStatus()))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accentCyan.opacity(0.5), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Output Node
    private func outputNode(in size: CGSize) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedNode = selectedNode == .output ? nil : .output
            }
        }) {
            VStack(spacing: 8) {
                Text("VERDICT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(statusColor(getOverallStatus()).opacity(0.1))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: getVerdictIcon())
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(statusColor(getOverallStatus()))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(statusColor(getOverallStatus()).opacity(0.4), lineWidth: 1)
                )
                
                Text(getVerdictText())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor(getOverallStatus()))
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Strategic Advice Bar
    private var strategicAdviceBar: some View {
        VStack(spacing: 6) {
            Text("STRATEGIC ASSESSMENT")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(2)
            
            Text(analysis.strategicAdvice)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Node Detail Panel
    private func nodeDetailPanel(for node: CircuitNode) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(node.title)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedNode = nil
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Educational Content
                Text(node.educationalContent(for: currentOrion))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                
                // Technical Details
                if let details = node.technicalDetails(for: currentOrion) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TECHNICAL DATA")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(1)
                        
                        ForEach(details, id: \.key) { detail in
                            HStack {
                                Text(detail.key)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(detail.value)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(boardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentCyan.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.5).ignoresSafeArea())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                selectedNode = nil
            }
        }
    }
    
    // MARK: - Helpers
    private func statusColor(_ status: SignalStatus) -> Color {
        switch status {
        case .positive: return activeGreen
        case .negative: return activeRed
        case .neutral: return neutralGray
        }
    }
    
    private func getTrendStatus() -> SignalStatus {
        currentOrion.components.trend > 15 ? .positive : (currentOrion.components.trend < 8 ? .negative : .neutral)
    }
    
    private func getMomentumStatus() -> SignalStatus {
        currentOrion.components.momentum > 15 ? .positive : (currentOrion.components.momentum < 8 ? .negative : .neutral)
    }
    
    private func getVolumeStatus() -> SignalStatus {
        currentOrion.components.structure > 20 ? .positive : (currentOrion.components.structure < 12 ? .negative : .neutral)
    }
    
    private func getOverallStatus() -> SignalStatus {
        currentOrion.score > 60 ? .positive : (currentOrion.score < 40 ? .negative : .neutral)
    }
    
    private func getVerdictText() -> String {
        if currentOrion.score >= 70 { return "STRONG BUY" }
        if currentOrion.score >= 55 { return "BUY" }
        if currentOrion.score >= 45 { return "HOLD" }
        if currentOrion.score >= 30 { return "SELL" }
        return "STRONG SELL"
    }
    
    private func getVerdictIcon() -> String {
        if currentOrion.score >= 55 { return "arrow.up.circle.fill" }
        if currentOrion.score >= 45 { return "minus.circle.fill" }
        return "arrow.down.circle.fill"
    }
}

// MARK: - Supporting Types

enum TimeframeMode {
    case daily, intraday
}

enum SignalStatus {
    case positive, negative, neutral
}

enum CircuitNode: Equatable {
    case trend, momentum, volume, cpu, output
    
    var title: String {
        switch self {
        case .trend: return "TREND ANALYSIS"
        case .momentum: return "MOMENTUM INDICATOR"
        case .volume: return "VOLUME & STRUCTURE"
        case .cpu: return "CONSENSUS ENGINE"
        case .output: return "FINAL VERDICT"
        }
    }
    
    func educationalContent(for orion: OrionScoreResult) -> String {
        switch self {
        case .trend:
            return "Trend analizi, fiyatın genel yonunu belirler. SMA 50 ve SMA 200 hareketli ortalamalari kullanilarak hesaplanir. Fiyat her iki ortalamanin uzerindeyse guclu yukselis trendi, altindaysa dusus trendi vardir."
        case .momentum:
            return "Momentum, fiyat hareketinin hizini ve gucunu olcer. RSI (Relative Strength Index) ve TSI kullanilir. RSI 70 uzerinde asiri alim, 30 altinda asiri satim sinyali verir."
        case .volume:
            return "Hacim ve yapi analizi, fiyat hareketlerinin arkasindaki gucun kalicilgini degerlendirir. Yuksek hacimli hareketler daha guvenilirdir. ADX gostergesi trend gucunu olcer."
        case .cpu:
            return "Konsensus motoru, tum gostergelerden gelen sinyalleri birlestirerek tek bir skor uretir. Her gosterge oylanir ve agirlikli ortalama alinir. Bu skor, genel piyasa durumunu yansitir."
        case .output:
            return "Nihai karar, konsensus skoruna gore belirlenir. 70 ustu guclu alim, 55-70 alim, 45-55 tut, 30-45 sat, 30 alti guclu sat olarak yorumlanir."
        }
    }
    
    func technicalDetails(for orion: OrionScoreResult) -> [(key: String, value: String)]? {
        switch self {
        case .trend:
            return [
                (key: "Score", value: String(format: "%.1f / 25", orion.components.trend)),
                (key: "Weight", value: "25%"),
                (key: "Status", value: orion.components.trend > 15 ? "Bullish" : "Bearish")
            ]
        case .momentum:
            return [
                (key: "Score", value: String(format: "%.1f / 25", orion.components.momentum)),
                (key: "Weight", value: "25%"),
                (key: "RSI Zone", value: orion.components.momentum > 18 ? "Overbought" : (orion.components.momentum < 7 ? "Oversold" : "Neutral"))
            ]
        case .volume:
            return [
                (key: "Structure", value: String(format: "%.1f / 35", orion.components.structure)),
                (key: "Weight", value: "35%"),
                (key: "Strength", value: orion.components.structure > 25 ? "Strong" : "Weak")
            ]
        case .cpu:
            return [
                (key: "Total Score", value: String(format: "%.0f / 100", orion.score)),
                (key: "Pattern", value: orion.components.patternDesc.isEmpty ? "None" : orion.components.patternDesc)
            ]
        case .output:
            return nil
        }
    }
}

// Preview disabled - uses live data
