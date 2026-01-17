import SwiftUI

// MARK: - ORION MOTHERBOARD VIEW (Full-Screen Circuit Board)
// Redesigned to match "Cyberpunk Dark" aesthetic with detailed module drill-down.

struct OrionMotherboardView: View {
    let analysis: MultiTimeframeAnalysis
    let symbol: String
    let candles: [Candle] // Data for charts
    
    @State private var selectedTimeframe: TimeframeMode = .daily
    @State private var selectedNode: CircuitNode? = nil
    @State private var flowPhase: CGFloat = 0
    
    // Theme matching the Dark Detail View
    // Background: Deep Dark Blue/Black
    // Theme - Harmonized with App Theme
    // Using a deep navy that blends with ArgusSanctum
    private let boardColor = Color(red: 0.05, green: 0.07, blue: 0.12) 
    private let cardBg = Color(red: 0.08, green: 0.10, blue: 0.16)
    private let traceColor = Color(red: 0.2, green: 0.2, blue: 0.3)
    
    // Accents
    private let activeGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let activeRed = Color(red: 0.9, green: 0.2, blue: 0.2)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let orange = Color(red: 1.0, green: 0.6, blue: 0.0)
    
    var currentOrion: OrionScoreResult {
        selectedTimeframe == .daily ? analysis.daily : analysis.intraday
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // LAYER 1: Background & Grid
                boardBackground
                
                // LAYER 2: Circuit Traces (Wires)
                circuitTraces(in: geo.size)
                
                // LAYER 3: Data Flow Animation
                dataFlowParticles(in: geo.size)
                
                // LAYER 4: Interactive Nodes
                VStack(spacing: 0) {
                    // Header
                    headerBar
                    
                    Spacer()
                    
                    // Main Board Layout
                    HStack(spacing: 0) {
                        // LEFT: Modules (Trend, Momentum, Volume)
                        inputStations(in: geo.size)
                            .frame(width: 110) // Reduced width
                        
                        // Spacer (Dynamic Gap)
                        Spacer(minLength: 40)
                        
                        // CENTER: Consensus CPU
                        cpuNode(in: geo.size)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16) // Slightly reduced padding
                    
                    Spacer()
                    
                    // Footer
                    strategicAdviceBar
                }
                
                // LAYER 5: Detail Overlay (The "Yekpare" Drill-down)
                if let node = selectedNode {
                    OrionModuleDetailView(
                        type: node,
                        symbol: symbol,
                        analysis: currentOrion,
                        candles: candles,
                        onClose: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedNode = nil
                            }
                        }
                    )
                    .transition(.move(edge: .trailing)) // Slide in from right like a drill-down
                    .zIndex(10)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("ANALIZ ÇEKİRDEĞİ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(2)
                Text(symbol)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Timeframe Selector
            HStack(spacing: 0) {
                timeframeButton(.intraday, label: "4H")
                timeframeButton(.daily, label: "1D")
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    private func timeframeButton(_ mode: TimeframeMode, label: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeframe = mode
            }
        }) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(selectedTimeframe == mode ? .black : .gray)
                .frame(width: 44, height: 32)
                .background(selectedTimeframe == mode ? cyan : Color.clear)
        }
    }
    
    // MARK: - Modules (Left Column)
    private func inputStations(in size: CGSize) -> some View {
        VStack(spacing: 20) {
            // Trend Module
            moduleCard(
                node: .trend,
                title: "TREND GÜCÜ",
                value: String(format: "%.0f", currentOrion.components.trend),
                max: 25,
                color: activeRed // Based on image 1 (Red box)
            )
            
            // Momentum Module
            moduleCard(
                node: .momentum,
                title: "MOMENTUM HIZI",
                value: String(format: "%.0f", currentOrion.components.momentum),
                max: 25,
                color: cyan // Based on image 1 style
            )
            
            // Volume Module
            moduleCard(
                node: .volume,
                title: "İŞLEM HACMİ",
                value: String(format: "%.0f", currentOrion.components.structure),
                max: 35,
                color: orange
            )
        }
    }
    
    private func moduleCard(node: CircuitNode, title: String, value: String, max: Double, color: Color) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedNode = node
            }
        }) {
            VStack(spacing: 12) {
                // Icon Area (e.g. Trend Line)
                Image(systemName: iconForNode(node))
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(value)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(color)
                            .frame(width: geo.size.width * min((Double(value) ?? 0) / max, 1.0))
                    }
                }
                .frame(height: 3) // Thinner progress bar
            }
            .padding(12) // Reduced padding inside card
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
            // Shadow
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForNode(_ node: CircuitNode) -> String {
        switch node {
        case .trend: return "chart.xyaxis.line"
        case .momentum: return "speedometer"
        case .volume: return "chart.bar.fill"
        default: return "circle"
        }
    }
    
    // MARK: - Consensus Node (Center)
    private func cpuNode(in size: CGSize) -> some View {
        Button(action: {
             // Maybe show summary detail?
        }) {
            ZStack {
                // Glow
                Circle()
                    .fill(cyan.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                // Outer Ring (Track)
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                // Active Ring (Gauge)
                Circle()
                    .trim(from: 0.15, to: 0.15 + (currentOrion.score / 100) * 0.7) // Partial arc
                    .stroke(
                         AngularGradient(
                            gradient: Gradient(colors: [activeRed, orange, activeGreen]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(90)) // Rotate to start at bottom/side
                
                // Inner Content
                VStack(spacing: 4) {
                    Text("KONSENSUS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Text(String(format: "%.0f", currentOrion.score))
                        .font(.system(size: 42, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(getVerdictText().uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(getVerdictColor())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(getVerdictColor().opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Traces
    private func circuitTraces(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let centerY = canvasSize.height / 2
            // Node connection points
            // Assuming simplified relative coordinates based on the layout
            
            let cpuCenter = CGPoint(x: canvasSize.width * 0.6, y: centerY) // Approx center of CPU
            let leftColX: CGFloat = 160 // Right edge of module cards
            
            // Connect Trend (Top)
            let trendY = centerY - 120
            drawConnection(context, from: CGPoint(x: leftColX, y: trendY), to: cpuCenter, color: activeRed)
            
            // Connect Momentum (Mid)
            let momY = centerY
            drawConnection(context, from: CGPoint(x: leftColX, y: momY), to: cpuCenter, color: cyan)
            
            // Connect Volume (Bottom)
            let volY = centerY + 120
            drawConnection(context, from: CGPoint(x: leftColX, y: volY), to: cpuCenter, color: orange)
        }
    }
    
    private func drawConnection(_ context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)
        
        let midX = (from.x + to.x) / 2
        
        // Circuit style: Horizontal -> Vertical -> Horizontal
        path.addLine(to: CGPoint(x: midX, y: from.y))
        path.addLine(to: CGPoint(x: midX, y: to.y))
        path.addLine(to: to)
        
        // Trace line
        context.stroke(path, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 2))
        
        // Connecting dots
        let dotSize: CGFloat = 6
        context.fill(Circle().path(in: CGRect(x: from.x - dotSize/2, y: from.y - dotSize/2, width: dotSize, height: dotSize)), with: .color(color))
        context.fill(Circle().path(in: CGRect(x: to.x - dotSize/2, y: to.y - dotSize/2, width: dotSize, height: dotSize)), with: .color(color))
    }
    
    // MARK: - Particles
    private func dataFlowParticles(in size: CGSize) -> some View {
        // Simplified particle animation logic reusing the path math
        // For brevity/performance, we can simulate just by showing moving dots along the known paths
        Canvas { context, canvasSize in
            let centerY = canvasSize.height / 2
            let cpuCenter = CGPoint(x: canvasSize.width * 0.6, y: centerY)
            let leftColX: CGFloat = 160
            
            // Calculate positions based on flowPhase (0.0 to 1.0)
            let trendStart = CGPoint(x: leftColX, y: centerY - 120)
            let momStart = CGPoint(x: leftColX, y: centerY)
            let volStart = CGPoint(x: leftColX, y: centerY + 120)
            
            // Draw particles
            drawParticle(context, from: trendStart, to: cpuCenter, progress: flowPhase, color: activeRed)
            drawParticle(context, from: momStart, to: cpuCenter, progress: (flowPhase + 0.3).truncatingRemainder(dividingBy: 1), color: cyan)
            drawParticle(context, from: volStart, to: cpuCenter, progress: (flowPhase + 0.6).truncatingRemainder(dividingBy: 1), color: orange)
        }
    }
    
    private func drawParticle(_ context: GraphicsContext, from: CGPoint, to: CGPoint, progress: CGFloat, color: Color) {
        let midX = (from.x + to.x) / 2
        
        // Interpolate position along the L-shape path
        // Segment 1: from -> (midX, from.y)
        // Segment 2: (midX, from.y) -> (midX, to.y)
        // Segment 3: (midX, to.y) -> to
        
        // Simplify: Just Linear interpolation (for now) to avoid complex path math in Canvas loop
        // Or implement robust segmented interpolation
        var current: CGPoint = .zero
        
        if progress < 0.33 {
            // Horizontal 1
            let localP = progress / 0.33
            current = CGPoint(x: from.x + (midX - from.x) * localP, y: from.y)
        } else if progress < 0.66 {
            // Vertical 2
            let localP = (progress - 0.33) / 0.33
            current = CGPoint(x: midX, y: from.y + (to.y - from.y) * localP)
        } else {
            // Horizontal 3
            let localP = (progress - 0.66) / 0.34
            current = CGPoint(x: midX + (to.x - midX) * localP, y: to.y)
        }
        
        // Draw glow ball
        let size: CGFloat = 8
        let rect = CGRect(x: current.x - size/2, y: current.y - size/2, width: size, height: size)
        context.fill(Circle().path(in: rect), with: .color(color))
        context.fill(Circle().path(in: rect.insetBy(dx: -4, dy: -4)), with: .color(color.opacity(0.4)))
    }
    
    private var boardBackground: some View {
        ZStack {
            boardColor.ignoresSafeArea()
            // Optional Circuit patterned background image or shader
        }
    }
    
    private var strategicAdviceBar: some View {
        HStack(spacing: 12) {
             Circle()
                .fill(getVerdictColor())
                .frame(width: 8, height: 8)
            
            Text("STRATEGIC ASSESSMENT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .overlay(
            Text(analysis.strategicAdvice)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
        )
    }
    
    // MARK: - Helpers
    private func getVerdictText() -> String {
         if currentOrion.score >= 55 { return "AL (BUY)" }
         if currentOrion.score >= 45 { return "TUT (HOLD)" }
         return "SAT (SELL)"
    }
    
    private func getVerdictColor() -> Color {
        if currentOrion.score >= 55 { return activeGreen }
        if currentOrion.score >= 45 { return orange }
        return activeRed
    }
}
