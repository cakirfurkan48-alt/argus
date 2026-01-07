import SwiftUI

// MARK: - THEME CONSTANTS
struct SanctumTheme {
    static let bg = RadialGradient(colors: [Color(hex: "080b14"), Color(hex: "020205")], center: .center, startRadius: 50, endRadius: 500)
    
    // Module Colors (Neon / Holographic)
    static let orionColor = Color(hex: "00ff9d") // Cyber Green
    static let atlasColor = Color(hex: "ffd700") // Gold
    static let aetherColor = Color(hex: "bd00ff") // Deep Purple
    static let hermesColor = Color(hex: "00d0ff") // Cyan
    static let athenaColor = Color(hex: "ff0055") // Neon Red
    static let demeterColor = Color(hex: "8b5a2b") // Earth Brown/Bronze
    static let chironColor = Color(hex: "ffffff") // Pure White Data
    
    // Glass Effect
    static let glassMaterial = Material.ultraThinMaterial
}

// MARK: - ARGUS SANCTUM VIEW
struct ArgusSanctumView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    // State
    @State private var selectedModule: ModuleType? = nil
    @State private var selectedBistModule: BistModuleType? = nil
    @State private var pulseAnimation = false
    @State private var rotateOrbit = false
    @State private var showDecision = false
    @State private var showDebateSheet = false
    
    // Modules enum for identification
    enum ModuleType: String, CaseIterable {
        case atlas = "ATLAS"
        case orion = "ORION"
        case aether = "AETHER"
        case hermes = "HERMES"
        case athena = "ATHENA"
        case demeter = "DEMETER"
        case chiron = "CHIRON"
        
        var icon: String {
            switch self {
            case .atlas: return "building.columns.fill"
            case .orion: return "chart.xyaxis.line"
            case .aether: return "globe.europe.africa.fill"
            case .hermes: return "newspaper.fill"
            case .athena: return "brain.head.profile"
            case .demeter: return "leaf.fill"
            case .chiron: return "graduationcap.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .atlas: return SanctumTheme.atlasColor
            case .orion: return SanctumTheme.orionColor
            case .aether: return SanctumTheme.aetherColor
            case .hermes: return SanctumTheme.hermesColor
            case .athena: return SanctumTheme.athenaColor
            case .demeter: return SanctumTheme.demeterColor
            case .chiron: return SanctumTheme.chironColor
            }
        }
        
        var description: String {
            switch self {
            case .atlas: return "Temel Analiz & Değerleme"
            case .orion: return "Teknik İndikatörler"
            case .aether: return "Makroekonomik Rejim"
            case .hermes: return "Haber & Duygu Analizi"
            case .athena: return "Akıllı Varyans (Smart Beta)"
            case .demeter: return "Sektör & Endüstri Analizi"
            case .chiron: return "Öğrenme & Risk Yönetimi"
            }
        }
    }
    
    // BIST Özel Modüller
    enum BistModuleType: String, CaseIterable {
        case bilanço = "BİLANÇO"   // Atlas karşılığı - Temel Analiz
        case grafik = "GRAFİK"     // Orion karşılığı - Teknik
        case sirkiye = "SİRKİYE"   // Aether karşılığı - Makro/Politik
        case kulis = "KULİS"       // Hermes karşılığı - Haberler
        case faktor = "FAKTÖR"     // Athena karşılığı - Smart Beta
        case sektor = "SEKTÖR"     // Demeter karşılığı - Sektör Rotasyonu
        case rejim = "REJİM"       // Yeni - Piyasa Modu
        case moneyflow = "AKIŞ"    // Yeni - Para Akışı
        
        var icon: String {
            switch self {
            case .bilanço: return "turkishlirasign.circle.fill"
            case .grafik: return "chart.xyaxis.line"
            case .sirkiye: return "flag.fill"
            case .kulis: return "text.bubble.fill"
            case .faktor: return "chart.bar.doc.horizontal.fill"
            case .sektor: return "chart.pie.fill"
            case .rejim: return "gauge.with.needle.fill"
            case .moneyflow: return "arrow.left.arrow.right.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .bilanço: return Color(hex: "D4AF37")     // Altın
            case .grafik: return Color(hex: "00E676")      // Yeşil
            case .sirkiye: return Color(hex: "C41E3A")     // Bayrak Kırmızı
            case .kulis: return Color(hex: "FF8C00")       // Turuncu
            case .faktor: return Color(hex: "1E90FF")      // Mavi
            case .sektor: return Color(hex: "E63946")      // Kırmızı
            case .rejim: return Color(hex: "9B59B6")       // Mor
            case .moneyflow: return Color(hex: "20B2AA")   // Teal
            }
        }
        
        var description: String {
            switch self {
            case .bilanço: return "BIST Temel Analiz & Mali Tablolar"
            case .grafik: return "Teknik Analiz & Fiyat Hareketi"
            case .sirkiye: return "Politik Ortam & Makro Analiz"
            case .kulis: return "Analist Konsensüsü & Haberler"
            case .faktor: return "Value, Momentum, Quality Faktörleri"
            case .sektor: return "Sektör Rotasyonu & Güç Analizi"
            case .rejim: return "Piyasa Rejimi (Boğa/Ayı/Nötr)"
            case .moneyflow: return "Hacim & Para Akışı Analizi"
            }
        }
    }
    

    // MARK: - Computed Views
    
    private var orbitingModulesView: some View {
        let orbitRadius: CGFloat = 130
        let moduleCount = Double(ModuleType.allCases.count)
        
        return ForEach(Array(ModuleType.allCases.enumerated()), id: \.element) { index, module in
            let angle = (2.0 * .pi / moduleCount) * Double(index) - .pi / 2.0
            let xOffset = orbitRadius * CGFloat(cos(angle))
            let yOffset = orbitRadius * CGFloat(sin(angle))
            
            OrbView(module: module, viewModel: viewModel, symbol: symbol)
                .offset(x: xOffset, y: yOffset)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedModule = module
                    }
                }
        }
    }
    
    // BIST Özel Orbit Görünümü
    private var bistOrbitingModulesView: some View {
        let orbitRadius: CGFloat = 130
        let moduleCount = Double(BistModuleType.allCases.count)
        
        return ForEach(Array(BistModuleType.allCases.enumerated()), id: \.element) { index, module in
            let angle = (2.0 * .pi / moduleCount) * Double(index) - .pi / 2.0
            let xOffset = orbitRadius * CGFloat(cos(angle))
            let yOffset = orbitRadius * CGFloat(sin(angle))
            
            BistOrbView(module: module)
                .offset(x: xOffset, y: yOffset)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedBistModule = module
                    }
                }
        }
    }
    
    
    var body: some View {
        ZStack {
            // 1. NEURAL BACKGROUND
            SanctumTheme.bg.ignoresSafeArea()
            NeuralNetworkBackground()
                .opacity(0.3)
            
            VStack {
                // Header with Price Info
                HStack(spacing: 12) {
                    CompanyLogoView(symbol: symbol, size: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(symbol)
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(.white)
                            
                            // BIST Badge
                            if symbol.uppercased().hasSuffix(".IS") {
                                Text("🇹🇷 BIST")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(4)
                            }
                        }
                        
                        if let quote = viewModel.quotes[symbol] {
                            let isBist = symbol.uppercased().hasSuffix(".IS")
                            HStack(spacing: 6) {
                                Text(String(format: isBist ? "₺%.0f" : "$%.2f", quote.currentPrice))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if let dp = quote.dp {
                                    Text(String(format: "%+.2f%%", dp))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(dp >= 0 ? .green : .red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((dp >= 0 ? Color.green : Color.red).opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Data Health Indicator
                    VStack(spacing: 2) {
                        Image(systemName: "eye.fill")
                            .font(.title3)
                            .foregroundColor(SanctumTheme.chironColor)
                            .shadow(color: .white, radius: 5)
                        if let dataHealth = viewModel.dataHealthBySymbol[symbol] {
                            Text("\(dataHealth.qualityScore)%")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
                
                // 2. THE CONVERGENCE (Main Council)
                ZStack {
                    // Central Core (Decision) - Tap to see debate
                    let isBist = symbol.uppercased().hasSuffix(".IS")
                    let anyModuleSelected = selectedModule != nil || selectedBistModule != nil
                    
                    CenterCoreView(symbol: symbol, viewModel: viewModel, showDecision: $showDecision)
                        .scaleEffect(anyModuleSelected ? 0.6 : 1.0)
                        .blur(radius: anyModuleSelected ? 5 : 0)
                        .animation(.spring(), value: anyModuleSelected)
                        .onTapGesture {
                            if viewModel.grandDecisions[symbol] != nil {
                                showDebateSheet = true
                            }
                        }
                    
                    // Orbiting Modules - BIST veya Global
                    if !anyModuleSelected {
                        if isBist {
                            bistOrbitingModulesView
                        } else {
                            orbitingModulesView
                        }
                    }
                }
                .frame(height: 350)
                
                Spacer()
                
                // 3. HOLO PANEL (Details when module selected)
                if selectedModule == nil {
                    VStack(spacing: 12) {
                        // Mini Chart
                        SanctumMiniChart(candles: viewModel.candles[symbol] ?? [])
                            .frame(height: 80)
                            .padding(.horizontal)
                        
                        // Info Strip (Universe + Transactions)
                        HStack(spacing: 16) {
                            // Universe Info
                            if let universeItem = viewModel.universeCache[symbol] {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text(universeItem.sources.first?.rawValue ?? "Scout")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Transaction Count
                            let txCount = viewModel.transactionHistory.filter { $0.symbol == symbol }.count
                            if txCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text("\(txCount) işlem")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Text("Modül Seçin")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.horizontal)
                    }
                    .transition(.opacity)
                    
                    // 4. ADVISOR PANEL (Bottom)
                    if let decision = viewModel.grandDecisions[symbol], !decision.advisors.isEmpty {
                        ArgusAdvisorsView(advisors: decision.advisors)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            
            // 3. HOLO PANEL (Full Screen Overlay) - Global
            if let module = selectedModule {
                HoloPanelView(module: module, viewModel: viewModel, symbol: symbol, onClose: {
                    withAnimation { selectedModule = nil }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // 4. BIST HOLO PANEL (Full Screen Overlay) - BIST Modülleri
            if let bistModule = selectedBistModule {
                BistHoloPanelView(module: bistModule, viewModel: viewModel, symbol: symbol, onClose: {
                    withAnimation { selectedBistModule = nil }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotateOrbit = true
            }
            
            // 📡 PREVIOUSLY: ArgusSanctumView tried to orchestrate everything here.
            // FIX (Step ID 12415): We removed that logic because it caused a race condition with TradingViewModel.
            // Now, we strictly observe `viewModel.grandDecisions[symbol]`.
            // The loading is triggered by StockDetailView calling `viewModel.loadArgusData`.
            
            // Show decision animation if ready
            if viewModel.grandDecisions[symbol] != nil {
                 withAnimation { showDecision = true }
            }
        }
        .onChange(of: viewModel.grandDecisions[symbol]) { newValue in
            if newValue != nil {
                withAnimation { showDecision = true }
            }
        }
        .sheet(isPresented: $showDebateSheet) {
            if let decision = viewModel.grandDecisions[symbol] {
                if symbol.uppercased().hasSuffix(".IS"), let bistData = decision.bistDetails {
                    // YERLİ KONSEY TARTIŞMASI 🇹🇷
                    BistDebateSheet(decision: bistData, isPresented: $showDebateSheet)
                } else {
                    // GLOBAL KONSEY TARTIŞMASI 🇺🇸
                    AgoraDebateSheet(decision: decision)
                }
            }
        }
    }
}

// MARK: - COMPONENTS

struct OrbView: View {
    let module: ArgusSanctumView.ModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Glow
                Circle()
                    .fill(module.color.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .blur(radius: 10)
                
                // Core
                Circle()
                    .fill(
                        LinearGradient(colors: [module.color.opacity(0.8), module.color.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                
                // Icon
                Image(systemName: module.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .shadow(color: module.color, radius: 8)
            
            // LOCALIZED ORB LABELS
            let label: String = {
                if symbol.uppercased().hasSuffix(".IS") {
                    switch module {
                    case .aether: return "SİRKİYE"
                    case .orion: return "TAHTA"
                    case .atlas: return "KASA"
                    case .hermes: return "KULİS"
                    case .chiron: return "KISMET"
                    default: return module.rawValue
                    }
                } else {
                    return module.rawValue
                }
            }()
            
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(module.color)
                .shadow(color: module.color, radius: 3)
        }
    }
}

// BIST Özel Orb Görünümü
struct BistOrbView: View {
    let module: ArgusSanctumView.BistModuleType
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Glow - Türkiye renkleri
                Circle()
                    .fill(module.color.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .blur(radius: 10)
                
                // Core - Gradient
                Circle()
                    .fill(
                        LinearGradient(colors: [module.color.opacity(0.9), module.color.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.6), module.color.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.5
                            )
                    )
                
                // Icon
                Image(systemName: module.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            .shadow(color: module.color, radius: 8)
            
            // Modül İsmi
            Text(module.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(module.color)
                .shadow(color: module.color, radius: 3)
        }
    }
}

struct CenterCoreView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Binding var showDecision: Bool
    
    @State private var rotateHulahup = false
    
    var body: some View {
        ZStack {
            // 1. Base Holo-Table
            Circle() // Inner Glass
                .fill(Material.ultraThinMaterial)
                .frame(width: 120, height: 120)
                .shadow(color: .cyan.opacity(0.3), radius: 20)
            
            // 2. Spinning Energy Field (Fast)
            Circle()
                .stroke(
                    AngularGradient(colors: [.cyan.opacity(0), .cyan, .cyan.opacity(0)], center: .center),
                    lineWidth: 2
                )
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(rotateHulahup ? 360 : 0))
                .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: rotateHulahup)
            
            // 3. The "Hulahup" Ring (Slow, 3D Tilted)
            // Outer Orbit
            Circle()
                .strokeBorder(
                    AngularGradient(gradient: Gradient(colors: [.blue.opacity(0), .white, .blue.opacity(0)]), center: .center),
                    lineWidth: 3
                )
                .frame(width: 220, height: 220)
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                .rotationEffect(.degrees(rotateHulahup ? 360 : 0))
                .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: rotateHulahup)
            
            // Inner Orbit (Counter Rotate)
            Circle()
                .strokeBorder(
                    AngularGradient(gradient: Gradient(colors: [.purple.opacity(0), .white.opacity(0.5), .purple.opacity(0)]), center: .center),
                    lineWidth: 1
                )
                .frame(width: 180, height: 180)
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                .rotationEffect(.degrees(rotateHulahup ? -360 : 0))
                .animation(.linear(duration: 15).repeatForever(autoreverses: false), value: rotateHulahup)

            
            // 4. Decision Text / Loading
            if showDecision {
                VStack {
                    Text("KONSEY KARARI")
                        .font(.caption2)
                        .tracking(2)
                        .foregroundColor(.gray)
                    
                    if let decision = viewModel.grandDecisions[symbol] {
                        Text(decision.action.rawValue)
                            .font(.system(size: 18, weight: .black, design: .rounded)) // Size fixed to prevent truncation
                            .foregroundColor(
                                decision.action == .aggressiveBuy || decision.action == .accumulate ? .green :
                                decision.action == .aggressiveBuy || decision.action == .accumulate ? .green :
                                (decision.action == .liquidate || decision.action == .trim ? .red : .yellow)
                            )
                            .shadow(color: decision.action == .aggressiveBuy ? .green : .blue, radius: 10)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                            .minimumScaleFactor(0.8) // Ensure text fits
                        
                        Text("\(Int(decision.confidence * 100))% Güven")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                        
                        // VETO BADGE - Show why signal was blocked
                        if !decision.vetoes.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.system(size: 8))
                                Text(decision.vetoes.first?.module ?? "")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                        }
                    } else {
                        Text("...")
                            .font(.title)
                    }
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            rotateHulahup = true
        }
    }
}

struct HoloPanelView: View {
    let module: ArgusSanctumView.ModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    let onClose: () -> Void
    
    // State for async data loading
    @State private var chironPulseWeights: ChironModuleWeights?
    @State private var chironCorseWeights: ChironModuleWeights?
    @State private var showBacktestSheet = false
    @State private var showInfoCard = false
    @State private var showImmersiveChart = false // NEW: Full Screen Charts
    
    var body: some View {
        ZStack { // Wrap in ZStack for Info Card Overlay
            VStack(spacing: 0) {
                // Holo Header
                HStack {
                    Image(systemName: module.icon)
                        .foregroundColor(module.color)
                    
                    // LOCALIZED NAMES FOR BIST (Eski Borsacı Jargonu)
                    let title: String = {
                        if symbol.uppercased().hasSuffix(".IS") {
                            switch module {
                            case .aether: return "SİRKİYE"
                            case .orion: return "TAHTA"
                            case .atlas: return "KASA"
                            case .hermes: return "KULİS"
                            case .chiron: return "KISMET"
                            default: return module.rawValue
                            }
                        } else {
                            return module.rawValue
                        }
                    }()
                    
                    Text(title)
                        .font(.headline)
                        .bold()
                        .tracking(2)
                        .foregroundColor(.white)
                    
                    // NEW: Info Button
                    Button(action: { withAnimation { showInfoCard = true } }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(module.color.opacity(0.8))
                    }
                    
                    // NEW: Expand Chart Button (Only if candles exist)
                    if viewModel.candles[symbol] != nil && (module == .orion || module == .atlas || module == .aether) {
                        Button(action: { showImmersiveChart = true }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16))
                                .foregroundColor(module.color.opacity(0.8))
                        }
                        .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding()
                .background(module.color.opacity(0.2))
                
                Divider().background(module.color)
                
                // Holo Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(module.description)
                            .font(.caption)
                            .italic()
                            .foregroundColor(.gray)
                        
                        // DYNAMIC CONTENT BASED ON MODULE
                        contentForModule(module)
                    }
                    .padding()
                }
            }
            .task {
                if module == .chiron {
                    // Load weights from ChironWeightStore
                    chironPulseWeights = await ChironWeightStore.shared.getWeights(symbol: symbol, engine: .pulse)
                    chironCorseWeights = await ChironWeightStore.shared.getWeights(symbol: symbol, engine: .corse)
                }
            }
            
            // System Info Card Overlay
            if showInfoCard {
                SystemInfoCard(entity: mapModuleToEntity(module), isPresented: $showInfoCard)
                    .zIndex(200)
            }
        }
        .fullScreenCover(isPresented: $showImmersiveChart) {
            ArgusImmersiveChartView(
                viewModel: viewModel,
                symbol: symbol
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SanctumTheme.glassMaterial)
        .cornerRadius(0)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(LinearGradient(colors: [module.color, .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
    }
    
    // Helper to map UI Module to System Entity
    private func mapModuleToEntity(_ module: ArgusSanctumView.ModuleType) -> ArgusSystemEntity {
        switch module {
        case .atlas: return .atlas
        case .orion: return .orion
        case .aether: return .aether
        case .hermes: return .hermes
        case .athena: return .argus // Athena maps to Argus main for now
        case .demeter: return .poseidon // Demeter maps to Poseidon (Sectors/Whales similar concept)
        case .chiron: return .chronos // Chiron/Chronos Time
        }
    }
    
    @ViewBuilder
    func contentForModule(_ module: ArgusSanctumView.ModuleType) -> some View {
        switch module {
        case .atlas:
            VStack(alignment: .leading, spacing: 16) {
                // BIST Specific: Yeni Öğretici Puanlama Kartı
                if symbol.uppercased().hasSuffix(".IS") {
                    AtlasBistScoreCard(symbol: symbol)
                    BistDividendCard(symbol: symbol)
                    BistCapitalIncreaseCard(symbol: symbol)
                }

                // NEW: Global Module Detail Card
                if let grandDecision = viewModel.grandDecisions[symbol],
                   let atlasDecision = grandDecision.atlasDecision {
                    // Convert AtlasDecision to CouncilDecision for the common view
                    let councilDecision = CouncilDecision(
                        symbol: atlasDecision.symbol,
                        action: atlasDecision.action,
                        netSupport: atlasDecision.netSupport,
                        approveWeight: 0, // Atlas uses different weighting, simplified for UI
                        vetoWeight: 0,
                        isStrongSignal: atlasDecision.isStrongSignal,
                        isWeakSignal: !atlasDecision.isStrongSignal && atlasDecision.netSupport > 0.1,
                        winningProposal: atlasDecision.winningProposal.map { prop in
                            CouncilProposal(
                                proposer: prop.proposer,
                                proposerName: prop.proposerName,
                                action: prop.action,
                                confidence: prop.confidence,
                                reasoning: prop.reasoning,
                                entryPrice: nil,
                                stopLoss: nil,
                                target: prop.targetPrice
                            )
                        },
                        allProposals: [], // Not needed for card view
                        votes: atlasDecision.votes.map { vote in
                            CouncilVote(
                                voter: vote.voter,
                                voterName: vote.voterName,
                                decision: vote.decision,
                                reasoning: vote.reasoning,
                                weight: vote.weight
                            )
                        },
                        vetoReasons: atlasDecision.vetoReasons,
                        timestamp: atlasDecision.timestamp
                    )
                    
                    GlobalModuleDetailCard(
                        moduleName: "Atlas",
                        decision: councilDecision,
                        moduleColor: SanctumTheme.atlasColor,
                        moduleIcon: "building.columns.fill"
                    )
                } else if viewModel.failedFundamentals.contains(symbol) {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Temel Veri Alınamadı")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("FMP servisinden veri çekilemedi. Lütfen daha sonra tekrar deneyin.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(SanctumTheme.atlasColor)
                        Text("Atlas Konseyi toplanıyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            
        case .orion:
            VStack(alignment: .leading, spacing: 16) {
                // BIST: Rölatif Güç Analizi (Endekse Göre Performans)
                if symbol.uppercased().hasSuffix(".IS") {
                    OrionRelativeStrengthCard(symbol: symbol)
                }
                
                // NEW: Global Module Detail Card
                if let grandDecision = viewModel.grandDecisions[symbol] {
                    GlobalModuleDetailCard(
                        moduleName: "Orion",
                        decision: grandDecision.orionDecision,
                        moduleColor: SanctumTheme.orionColor,
                        moduleIcon: "chart.xyaxis.line"
                    )
                }
                
                // Technical Score
                // Backtest Button (Only visible if data exists)
                if viewModel.orionScores[symbol] != nil {
                    Button(action: {
                        showBacktestSheet = true
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Backtest Çalıştır")
                                .font(.caption)
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(SanctumTheme.orionColor.opacity(0.3))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 4)
                    .sheet(isPresented: $showBacktestSheet) {
                        OrionBacktestView(symbol: symbol, candles: viewModel.candles[symbol] ?? [])
                    }
                } else {
                    // Loading State
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(SanctumTheme.orionColor)
                        Text("Orion Konseyi toplanıyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            
        case .aether:
            if symbol.uppercased().hasSuffix(".IS") {
                // SİRKİYE (BIST)
                SirkiyeDashboardView(viewModel: viewModel)
                    .padding(.vertical, 8)
            } else {
                // AETHER (Global)
                VStack(alignment: .leading, spacing: 16) {
                    // NEW: Global Module Detail Card
                    if let grandDecision = viewModel.grandDecisions[symbol] {
                        let aetherDecision = grandDecision.aetherDecision
                        // Convert AetherDecision to CouncilDecision
                        let councilDecision = CouncilDecision(
                            symbol: symbol,
                            action: .hold, // Aether uses Stance (riskOn/Off), mapping to Hold for generic UI or update logic later
                            netSupport: aetherDecision.netSupport,
                            approveWeight: 0,
                            vetoWeight: 0,
                            isStrongSignal: abs(aetherDecision.netSupport) > 0.5,
                            isWeakSignal: abs(aetherDecision.netSupport) > 0.2,
                            winningProposal: CouncilProposal(
                                proposer: "Aether",
                                proposerName: "Aether Konseyi",
                                action: .hold,
                                confidence: 1.0,
                                reasoning: "Piyasa Rejimi: \(aetherDecision.marketMode.rawValue)\nDuruş: \(aetherDecision.stance.rawValue)",
                                entryPrice: nil,
                                stopLoss: nil,
                                target: nil
                            ),
                            allProposals: [],
                            votes: [],
                            vetoReasons: [],
                            timestamp: Date()
                        )
                        
                        GlobalModuleDetailCard(
                            moduleName: "Aether",
                            decision: councilDecision,
                            moduleColor: SanctumTheme.aetherColor,
                            moduleIcon: "globe.europe.africa.fill"
                        )
                    } else {
                        // Loading State
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(SanctumTheme.aetherColor)
                            Text("Aether Konseyi toplanıyor...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    
                    // NEW: Aether v5 Dashboard Card (Compact)
                    if let macro = viewModel.macroRating {
                        AetherDashboardCard(rating: macro, isCompact: true)
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.purple)
                            Text("Makro veriler yükleniyor...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            
        case .hermes:
            VStack(alignment: .leading, spacing: 16) {
                // BIST: Analist Konsensüsü
                if symbol.uppercased().hasSuffix(".IS") {
                    HermesAnalystCard(symbol: symbol, currentPrice: viewModel.quotes[symbol]?.currentPrice ?? 0)
                }
                
                // NEW: Global Module Detail Card
                if let grandDecision = viewModel.grandDecisions[symbol],
                   let hermesDecision = grandDecision.hermesDecision {
                    // Convert HermesDecision to CouncilDecision
                    let councilDecision = CouncilDecision(
                        symbol: symbol,
                        action: .hold, // Hermes is sentiment based
                        netSupport: hermesDecision.netSupport,
                        approveWeight: 0,
                        vetoWeight: 0,
                        isStrongSignal: hermesDecision.isHighImpact,
                        isWeakSignal: !hermesDecision.isHighImpact && hermesDecision.netSupport > 0.3,
                        winningProposal: CouncilProposal(
                            proposer: "Hermes",
                            proposerName: "Hermes Habercisi",
                            action: .hold,
                            confidence: 1.0,
                            reasoning: "Duygu Durumu: \(hermesDecision.sentiment.rawValue)\nEtki: \(hermesDecision.isHighImpact ? "YÜKSEK" : "Normal")",
                            entryPrice: nil,
                            stopLoss: nil,
                            target: nil
                        ),
                        allProposals: [],
                        votes: [],
                        vetoReasons: [],
                        timestamp: Date()
                    )
                    
                    GlobalModuleDetailCard(
                        moduleName: "Hermes",
                        decision: councilDecision,
                        moduleColor: SanctumTheme.hermesColor,
                        moduleIcon: "gavel.fill"
                    )
                } else {
                    // Loading State
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(SanctumTheme.hermesColor)
                        Text("Hermes Konseyi toplanıyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                
                // Manual Analysis Button
                Button(action: {
                    Task {
                        await viewModel.analyzeOnDemand(symbol: symbol)
                    }
                }) {
                    HStack {
                        if viewModel.isLoadingNews {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(viewModel.isLoadingNews ? "Analiz Ediliyor..." : "Haberleri Tara")
                            .font(.caption)
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                }
                .disabled(viewModel.isLoadingNews)
                
                // News Insights
                let insights = viewModel.newsInsightsBySymbol[symbol] ?? []
                if !insights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Haber Analizi")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ForEach(Array(insights.prefix(5))) { insight in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(insight.headline)
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                Text(insight.impactSentenceTR)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(3)
                                
                                HStack {
                                    // Sentiment Badge
                                    Text(insight.sentiment.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((insight.sentiment == .strongPositive || insight.sentiment == .weakPositive) ? Color.green.opacity(0.3) : ((insight.sentiment == .strongNegative || insight.sentiment == .weakNegative) ? Color.red.opacity(0.3) : Color.gray.opacity(0.3)))
                                        .cornerRadius(4)
                                        .foregroundColor(.white)
                                    
                                    // Impact Score
                                    Text("Etki: \(Int(insight.impactScore))")
                                        .font(.caption2)
                                        .foregroundColor(insight.impactScore > 60 ? .green : (insight.impactScore < 40 ? .red : .gray))
                                    
                                    Spacer()
                                    
                                    // Time
                                    Text(insight.createdAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                } else if let summaries = viewModel.hermesSummaries[symbol], !summaries.isEmpty {
                    // Fallback to old summaries
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Haber Özetleri")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ForEach(Array(summaries.prefix(5))) { summary in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.summaryTR)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(3)
                                
                                HStack {
                                    Text("Etki: \(summary.impactScore)")
                                        .font(.caption2)
                                        .foregroundColor(summary.impactScore > 60 ? .green : (summary.impactScore < 40 ? .red : .gray))
                                    
                                    Spacer()
                                    
                                    Text(summary.mode.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "newspaper")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Henüz haber analizi yok")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Yukarıdaki butona tıklayarak haber taraması başlatın")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            
        case .athena:
            if let athena = viewModel.athenaResults[symbol] {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Smart Beta Puan:").foregroundColor(.white)
                        Spacer()
                        Text("\(Int(athena.factorScore))")
                            .font(.title)
                            .bold()
                            .foregroundColor(athena.factorScore > 50 ? .green : .red)
                    }
                    
                    // Factor breakdown
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Momentum:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(athena.momentumFactorScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Value:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(athena.valueFactorScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Quality:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(athena.qualityFactorScore))").foregroundColor(.white)
                        }
                    }
                    .font(.caption)
                    
                    Text(athena.styleLabel)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                Text("Athena analizi yükleniyor...")
                    .italic().foregroundColor(.gray)
            }
            
        case .demeter:
            // Find relevant sector for this symbol (simplified: show first available or Technology default)
            let demeterScore = viewModel.demeterScores.first(where: { $0.sector == .XLK }) ?? viewModel.demeterScores.first
            
            if let demeter = demeterScore {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sektör Puanı:").foregroundColor(.white)
                        Spacer()
                        Text("\(Int(demeter.totalScore))")
                            .font(.title)
                            .bold()
                            .foregroundColor(demeter.totalScore > 50 ? .green : .red)
                    }
                    
                    Text("Sektör: \(demeter.sector.name)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Component breakdown
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Momentum:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.momentumScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Şok Etkisi:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.shockImpactScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Rejim:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.regimeScore))").foregroundColor(.white)
                        }
                        HStack {
                            Text("Genişlik:").foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(demeter.breadthScore))").foregroundColor(.white)
                        }
                    }
                    .font(.caption)
                    
                    // Active shocks
                    if !demeter.activeShocks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aktif Şoklar:").font(.caption).foregroundColor(.orange)
                            ForEach(demeter.activeShocks) { shock in
                                Text("• \(shock.type.displayName) \(shock.direction.symbol)")
                                    .font(.caption2)
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                        }
                    }
                    
                    Text("Değerlendirme: \(demeter.grade)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(demeter.totalScore > 60 ? .green : (demeter.totalScore > 40 ? .yellow : .red))
                }
            } else {
                VStack(spacing: 8) {
                    Text("Sektör analizi yükleniyor...")
                        .italic().foregroundColor(.gray)
                    Text("Demeter verisi için lütfen bekleyin veya seç modülünden yükletin.")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            
        case .chiron:
            // Chiron - Learning & Risk Management
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Chiron Öğrenme Sistemi")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Regime from ArgusDecisions if available
                if let decision = viewModel.argusDecisions[symbol],
                   let chironResult = decision.chironResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Market Rejimi")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(chironResult.regime.descriptor)
                                .font(.headline)
                                .bold()
                                .foregroundColor(chironResult.regime == .trend ? .green : 
                                                chironResult.regime == .riskOff ? .red : .yellow)
                        }
                        
                        Text(chironResult.explanationTitle)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text(chironResult.explanationBody)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // PULSE Weights (Short-term)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.purple)
                        Text("PULSE Ağırlıkları (Kısa Vade)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                    }
                    
                    if let weights = chironPulseWeights {
                        chironWeightProgressRows(weights: weights, color: .purple)
                        
                        Text(weights.reasoning)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor...")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
                
                // CORSE Weights (Long-term)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "tortoise.fill")
                            .foregroundColor(.blue)
                        Text("CORSE Ağırlıkları (Uzun Vade)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                    }
                    
                    if let weights = chironCorseWeights {
                        chironWeightProgressRows(weights: weights, color: .blue)
                        
                        Text(weights.reasoning)
                            .font(.caption2)
                            .italic()
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    } else {
                        Text("Varsayılan ağırlıklar kullanılıyor...")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Learning tips
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 Nasıl Öğreniyor?")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Text("Chiron, geçmiş kararlardan ve fiyat hareketlerinden öğrenerek modül ağırlıklarını dinamik olarak ayarlar. Başarılı modüllerin ağırlığı artar.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    func ratioRow(_ label: String, value: Double?, isPercentage: Bool = false) -> some View {
        if let v = value {
            HStack {
                Text(label)
                    .foregroundColor(.gray)
                Spacer()
                if isPercentage {
                    Text(String(format: "%.1f%%", v * 100))
                        .foregroundColor(.white)
                } else {
                    Text(String(format: "%.2f", v))
                        .foregroundColor(.white)
                }
            }
            .font(.caption)
        }
    }
    
    @ViewBuilder
    func scoreBreakdownRow(_ label: String, score: Double, max: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(score / max > 0.6 ? Color.green : (score / max > 0.4 ? Color.yellow : Color.red))
                        .frame(width: geometry.size.width * CGFloat(min(score / max, 1.0)), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(score))/\(Int(max))")
                .font(.caption2)
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    func componentProgressRow(_ label: String, score: Double, max: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(score / max, 1.0)), height: 10)
                }
            }
            .frame(height: 10)
            
            Text("\(Int(score))/\(Int(max))")
                .font(.caption2)
                .bold()
                .foregroundColor(.white)
                .frame(width: 45, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    func chironWeightProgressRows(weights: ChironModuleWeights, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            chironWeightRow("Orion", weight: weights.orion, color: .cyan)
            chironWeightRow("Atlas", weight: weights.atlas, color: .yellow)
            chironWeightRow("Aether", weight: weights.aether, color: .purple)
            chironWeightRow("Hermes", weight: weights.hermes, color: .orange)
            chironWeightRow("Cronos", weight: weights.cronos, color: .gray)
        }
    }
    
    @ViewBuilder
    func chironWeightRow(_ label: String, weight: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 55, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(weight, 1.0)), height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(weight * 100))%")
                .font(.caption2)
                .foregroundColor(.white)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// Neural BG Animation (Network Nodes)
struct NeuralNetworkBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<10) { _ in
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: CGFloat.random(in: 2...5))
                        .offset(x: CGFloat.random(in: 0...geometry.size.width), y: CGFloat.random(in: 0...geometry.size.height))
                }
            }
        }
    }
}

// MARK: - Sanctum Mini Chart
struct SanctumMiniChart: View {
    let candles: [Candle]
    
    private var displayCandles: [Candle] {
        Array(candles.suffix(50))
    }
    
    private var priceRange: (min: Double, max: Double) {
        guard !displayCandles.isEmpty else { return (0, 100) }
        let prices = displayCandles.flatMap { [$0.high, $0.low] }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 100
        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding, maxPrice + padding)
    }
    
    private var isPositive: Bool {
        guard let first = displayCandles.first, let last = displayCandles.last else { return true }
        return last.close >= first.open
    }
    
    var body: some View {
        GeometryReader { geometry in
            if displayCandles.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Grafik Yükleniyor...")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    Spacer()
                }
            } else {
                ZStack {
                    // Background gradient
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.3), Color.black.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Price line
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let range = priceRange
                        let priceSpan = range.max - range.min
                        
                        for (index, candle) in displayCandles.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(displayCandles.count - 1)
                            let y = height * (1 - CGFloat((candle.close - range.min) / priceSpan))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: isPositive ? [.green.opacity(0.6), .green] : [.red.opacity(0.6), .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: isPositive ? .green.opacity(0.5) : .red.opacity(0.5), radius: 4)
                    
                    // Area fill
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let range = priceRange
                        let priceSpan = range.max - range.min
                        
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        for (index, candle) in displayCandles.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(displayCandles.count - 1)
                            let y = height * (1 - CGFloat((candle.close - range.min) / priceSpan))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: isPositive ? [.green.opacity(0.2), .clear] : [.red.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}

// Color Hex Helper

// MARK: - BIST Holo Panel View
struct BistHoloPanelView: View {
    let module: ArgusSanctumView.BistModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    let onClose: () -> Void
    
    // Immersive Chart State
    @State private var showImmersiveChart = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Holo Header
            HStack {
                Image(systemName: module.icon)
                    .foregroundColor(module.color)
                
                Text(module.rawValue)
                    .font(.headline)
                    .bold()
                    .tracking(2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Expand Chart Button (Only for Grafik module)
                if module == .grafik, viewModel.candles[symbol] != nil {
                    Button(action: { showImmersiveChart = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(module.color)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.6))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding()
            .background(module.color.opacity(0.2))
            
            Divider().background(module.color)
            
            // Holo Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(module.description)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.gray)
                    
                    // DYNAMIC CONTENT BASED ON BIST MODULE
                    bistContentForModule(module)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.08, blue: 0.06), Color(red: 0.05, green: 0.03, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(LinearGradient(colors: [module.color, .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .onAppear {
            // On-demand BIST karar verisi çekimi
            if viewModel.grandDecisions[symbol]?.bistDetails == nil {
                Task {
                    await fetchBistDecisionIfNeeded()
                }
            }
        }
        .fullScreenCover(isPresented: $showImmersiveChart) {
            ArgusImmersiveChartView(
                viewModel: viewModel,
                symbol: symbol
            )
        }
    }
    
    // MARK: - On-Demand BIST Decision Fetcher
    private func fetchBistDecisionIfNeeded() async {
        // ONE-OFF FIX: BIST Portföyünü ve Bakiyesini Düzelt (16 TL Hatası için)
        if !UserDefaults.standard.bool(forKey: "bist_fix_applied_v1") {
            print("🔧 Applying BIST Price Fix v1...")
            await MainActor.run {
                viewModel.resetBistPortfolio()
            }
            UserDefaults.standard.set(true, forKey: "bist_fix_applied_v1")
        }
        
        // 1. Candle verisi al (HeimdallOrchestrator - Yahoo Fallback)
        // BorsaPy yetersiz kalırsa Yahoo devreye girer. Tutarlılık için Grafik kartıyla aynı kaynağı kullanıyoruz.
        guard let candles = try? await HeimdallOrchestrator.shared.requestCandles(
            symbol: symbol,
            timeframe: "1D",
            limit: 60
        ) else {
            print("⚠️ BistHoloPanel: \(symbol) için candle verisi alınamadı (Tüm kaynaklar başarısız)")
            return
        }
        
        guard candles.count >= 50 else {
            print("⚠️ BistHoloPanel: \(symbol) için yetersiz veri (\(candles.count) mum)")
            return
        }
        
        // 2. Sirkiye Input hazırla
        let usdTryQuote = await MainActor.run { viewModel.quotes["USD/TRY"] }
        let sirkiyeInput = SirkiyeEngine.SirkiyeInput(
            usdTry: usdTryQuote?.currentPrice ?? 35.0,
            usdTryPrevious: usdTryQuote?.previousClose ?? 35.0,
            dxy: 104.0,
            brentOil: 80.0,
            globalVix: 15.0,
            newsSnapshot: nil,
            currentInflation: 45.0,
            xu100Change: nil,
            xu100Value: nil,
            goldPrice: nil
        )
        
        // 3. ArgusGrandCouncil.convene() çağır
        let macro = MacroSnapshot.fromCached()
        let decision = await ArgusGrandCouncil.shared.convene(
            symbol: symbol,
            candles: candles,
            financials: nil,
            macro: macro,
            news: nil,
            engine: .pulse,
            sirkiyeInput: sirkiyeInput
        )
        
        // 4. grandDecisions'a yaz
        await MainActor.run {
            viewModel.grandDecisions[symbol] = decision
            print("✅ BistHoloPanel: \(symbol) için BIST kararı alındı (\(decision.action.rawValue))")
        }
    }
    
    @ViewBuilder
    private func bistContentForModule(_ module: ArgusSanctumView.BistModuleType) -> some View {
        // Backend'den BIST karar verilerini al
        let bistDetails = viewModel.grandDecisions[symbol]?.bistDetails
        
        switch module {
        case .grafik:
            if let detail = bistDetails?.grafik {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon
                )
            }
            // Teknik göstergeler (SAR, TSI, RSI)
            GrafikEducationalCard(symbol: symbol)
            
        case .bilanço:
            if let detail = bistDetails?.bilanco {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon
                )
            } else {
                AtlasBistScoreCard(symbol: symbol)
            }
            
        case .faktor:
            if let detail = bistDetails?.faktor {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon,
                    extraInfo: [
                        ExtraInfoItem(icon: "chart.bar.fill", label: "Value Skoru", value: "Hesaplandı", color: .blue),
                        ExtraInfoItem(icon: "bolt.fill", label: "Momentum", value: "Aktif", color: .orange),
                        ExtraInfoItem(icon: "checkmark.seal.fill", label: "Quality", value: "Yüksek", color: .green)
                    ]
                )
            } else {
                BistFaktorCard(symbol: symbol)
            }
            
        case .sektor:
            if let detail = bistDetails?.sektor {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon
                )
            } else {
                BistSektorCard()
            }
            
        case .rejim:
            if let detail = bistDetails?.rejim {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon,
                    extraInfo: [
                        ExtraInfoItem(icon: "globe", label: "Global Rejim", value: "Risk-On", color: .green),
                        ExtraInfoItem(icon: "turkishlirasign.circle", label: "TL Durumu", value: "Stabil", color: .yellow)
                    ]
                )
            } else {
                BistRejimCard()
            }
            
        case .moneyflow:
            if let detail = bistDetails?.akis {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon,
                    extraInfo: [
                        ExtraInfoItem(icon: "arrow.up.right", label: "Para Girişi", value: "Pozitif", color: .green),
                        ExtraInfoItem(icon: "person.3.fill", label: "Yabancı Akışı", value: "Nötr", color: .yellow)
                    ]
                )
            } else {
                BistMoneyFlowCard(symbol: symbol)
            }
            
        case .kulis:
            if let detail = bistDetails?.kulis {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon
                )
            }
            // Analist kartları (Hermes)
            HermesAnalystCard(symbol: symbol, currentPrice: viewModel.quotes[symbol]?.currentPrice ?? 0)
            
        case .sirkiye:
            // Sirkiye Dashboard (Makro Görünüm)
            SirkiyeDashboardView(viewModel: viewModel)
        }
    }
}
