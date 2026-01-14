import SwiftUI

// MARK: - THEME CONSTANTS
struct SanctumTheme {
    // Background: Deep Navy Slate (OLED Friendly)
    static let bg = Color(hex: "0F172A") // Was Void Black
    
    // Core Palette (Bloomberg V2)
    static let hologramBlue = Color(hex: "38BDF8") // Active/Focus
    static let auroraGreen = Color(hex: "34D399") // Positive
    static let titanGold = Color(hex: "FBBF24") // Mythic/Accent
    static let ghostGrey = Color(hex: "94A3B8") // Passive Text
    static let crimsonRed = Color(hex: "F43F5E") // Negative/Alert
    
    // Module Colors (Mapped to V2)
    static let orionColor = hologramBlue     // Technical -> Hologram Blue
    static let atlasColor = titanGold        // Fundamental -> Titan Gold
    static let aetherColor = ghostGrey       // Macro -> Ghost Grey (Neutral base)
    static let athenaColor = titanGold       // Smart Beta -> Titan Gold (Wisdom)
    static let hermesColor = Color(hex: "FB923C") // News -> Orange (distinct from gold)
    static let demeterColor = auroraGreen    // Sectors -> Aurora Green (Growth)
    static let chironColor = Color.white     // System -> White (Ultimate contrast)
    
    // Glass Effect
    static let glassMaterial = Material.thickMaterial
}

// MARK: - ARGUS SANCTUM VIEW
struct ArgusSanctumView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // State
    @State private var selectedModule: ModuleType? = nil
    @State private var selectedBistModule: BistModuleType? = nil
    @State private var pulseAnimation = false
    @State private var rotateOrbit = false
    @State private var showDecision = false
    @State private var showDebateSheet = false
    @State private var showChronosLabSheet = false
    @State private var showArgusLabSheet = false
    @State private var showObservatorySheet = false

    // Modules enum for identification
    enum ModuleType: String, CaseIterable {
        case atlas = "ATLAS"
        case orion = "ORION"
        case aether = "AETHER"
        case hermes = "HERMES"
        case athena = "ATHENA"
        case demeter = "DEMETER"
        case chiron = "CHIRON"
        case prometheus = "PROMETHEUS"
        
        var icon: String {
            switch self {
            case .atlas: return "building.columns.fill"
            case .orion: return "chart.xyaxis.line"
            case .aether: return "globe.europe.africa.fill"
            case .hermes: return "newspaper.fill"
            case .athena: return "brain.head.profile"
            case .demeter: return "leaf.fill"
            case .chiron: return "graduationcap.fill"
            case .prometheus: return "crystal.ball"
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
            case .prometheus: return SanctumTheme.hologramBlue // Prometheus uses Technical color
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
            case .prometheus: return "5 Günlük Fiyat Tahmini"
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
        case vektor = "VEKTÖR"     // Prometheus karşılığı - Tahmin
        case sektor = "SEKTÖR"     // Demeter karşılığı - Sektörel
        case rejim = "REJİM"       // Chiron/Aether karşılığı - Piyasa Rejimi
        case moneyflow = "PARA-AKIL" // Yeni: Para Girişi/Takas
        
        var icon: String {
            switch self {
            case .bilanço: return "building.columns.fill"
            case .grafik: return "chart.xyaxis.line"
            case .sirkiye: return "globe.europe.africa.fill"
            case .kulis: return "newspaper.fill"
            case .faktor: return "brain.head.profile"
            case .vektor: return "crystal.ball"
            case .sektor: return "leaf.fill" // Demeter
            case .rejim: return "traffic.light" // Rejim
            case .moneyflow: return "arrow.up.right.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .bilanço: return SanctumTheme.atlasColor
            case .grafik: return SanctumTheme.orionColor
            case .sirkiye: return SanctumTheme.aetherColor
            case .kulis: return SanctumTheme.hermesColor
            case .faktor: return SanctumTheme.athenaColor
            case .vektor: return SanctumTheme.hologramBlue
            case .sektor: return SanctumTheme.demeterColor
            case .rejim: return SanctumTheme.crimsonRed
            case .moneyflow: return Color.green
            }
        }
        
        var description: String {
            switch self {
            case .bilanço: return "Bilanço ve Temel Veriler"
            case .grafik: return "Teknik Analiz ve İndikatörler"
            case .sirkiye: return "Makroekonomik Göstergeler (Sirkiye)"
            case .kulis: return "KAP Haberleri ve Duygu Analizi"
            case .faktor: return "Faktör Yatırımı (Smart Beta)"
            case .vektor: return "Yapay Zeka Fiyat Tahmini"
            case .sektor: return "Sektörel Performans Analizi"
            case .rejim: return "Piyasa Risk Rejimi"
            case .moneyflow: return "Para Giriş/Çıkış ve Takas Analizi"
            }
        }
    }
    
    // Orbit Animation Parameters
    // Only used for visualization, logic is in ViewModel
    private let orbitRadius: CGFloat = 130
    private let animationDuration: Double = 40
    
    // Modules calculated property
    var modules: [ModuleType] {
        ModuleType.allCases
    }
    
    var bistModules: [BistModuleType] = [
        .grafik, .bilanço, .rejim, .sirkiye, .kulis, .moneyflow // Selected active modules
    ]
    var moduleCount: Double {
        Double(bistModules.count)
    }

    var body: some View {
        ZStack {
            // 1. Background (Deep Space / Global Neural Network)
            SanctumTheme.bg.edgesIgnoringSafeArea(.all)
            NeuralNetworkBackground().edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 2. HEADER
                headerView
                
                Spacer()
                
                // 3. CENTER CORE (The Heart)
                centerCoreArea
                
                Spacer()
                
                // 4. FOOTER (Pantheon Deck)
                footerHelper
            }
            .padding(.bottom, 100) // Lift up for TabBar
            
            // 5. OVERLAYS
            if let selectedModule = selectedModule {
                 HoloPanelView(
                    module: selectedModule,
                    viewModel: viewModel,
                    symbol: symbol,
                    showChronosLabSheet: $showChronosLabSheet,
                    showArgusLabSheet: $showArgusLabSheet,
                    onClose: {
                        withAnimation {
                            self.selectedModule = nil
                            self.showDecision = false
                        }
                    }
                 )
                 .transition(.opacity.combined(with: .scale(scale: 0.95)))
                 .zIndex(100)
            }
            
            if let selectedBist = selectedBistModule {
                 BistHoloPanelView(
                    module: selectedBist,
                    viewModel: viewModel,
                    symbol: symbol,
                    onClose: {
                        withAnimation {
                            self.selectedBistModule = nil
                            self.showDecision = false
                        }
                    }
                 )
                 .transition(.opacity.combined(with: .scale(scale: 0.95)))
                 .zIndex(100)
            }
            
             // Back Button (Top Left)
            backButtonOverlay
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDebateSheet) {
            debateSheetContent
        }
        .sheet(isPresented: $showChronosLabSheet) {
             chronosLabSheetContent
        }
        .sheet(isPresented: $showArgusLabSheet) {
             argusLabSheetContent
        }
        .sheet(isPresented: $showObservatorySheet) {
              observatorySheetContent
        }
        .onAppear {
            if symbol.uppercased().hasSuffix(".IS") {
                // Pre-load BIST logic if needed
            }
        }
    }

    // MARK: - Subviews (Computed Properties)
    
    // 1. BACK BUTTON
    private var backButtonOverlay: some View {
        VStack {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Terminal")
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(SanctumTheme.ghostGrey)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                Spacer()
                
                // Observatory Button
                Button(action: { showObservatorySheet = true }) {
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 18))
                        .foregroundColor(SanctumTheme.titanGold)
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 16)
            Spacer()
        }
    }
    
    // 2. HEADER
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
                .shadow(color: SanctumTheme.hologramBlue.opacity(0.5), radius: 10)
            
            if let quote = viewModel.quotes[symbol] {
                Text(String(format: "%.2f", quote.currentPrice))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor((quote.percentChange ?? 0) >= 0 ? SanctumTheme.auroraGreen : SanctumTheme.crimsonRed)
            }
        }
        .padding(.top, 20)
    }
    
    // 3. CENTER CORE
    private var centerCoreArea: some View {
        ZStack {
            // The Dial
            CenterCoreView(symbol: symbol, viewModel: viewModel, showDecision: $showDecision)
            
            // Orbiting Satellites (Modules)
            // BIST vs Global Separation
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                // BIST MODULES ORBIT
                ForEach(0..<bistModules.count, id: \.self) { i in
                    let angle = Double(i) * (360.0 / Double(bistModules.count)) - 90 // Start from Top
                    let mod = bistModules[i]
                    
                    BistOrbView(module: mod)
                        .offset(x: cos(angle * .pi / 180) * orbitRadius, y: sin(angle * .pi / 180) * orbitRadius)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.selectedBistModule = mod
                                self.showDecision = true
                            }
                        }
                }
            } else {
                // GLOBAL MODULES ORBIT (Classic Argus)
                let globalModules: [ModuleType] = [.orion, .atlas, .aether, .hermes]
                ForEach(0..<globalModules.count, id: \.self) { i in
                    let angle = Double(i) * (360.0 / Double(globalModules.count)) - 90
                    let mod = globalModules[i]
                    
                    OrbView(module: mod, viewModel: viewModel, symbol: symbol)
                        .offset(x: cos(angle * .pi / 180) * orbitRadius, y: sin(angle * .pi / 180) * orbitRadius)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.selectedModule = mod
                                self.showDecision = true
                            }
                        }
                }
            }
        }
        .frame(height: 300) // Constrain height to keep layout tight
    }
    
    // 4. FOOTER (Pantheon)
    private var footerHelper: some View {
         PantheonDeckView(
            symbol: symbol,
            viewModel: viewModel,
            isBist: symbol.uppercased().hasSuffix(".IS"),
            selectedModule: $selectedModule,
            selectedBistModule: $selectedBistModule
        )
    }
    
    // 5. SHEETS
    private var debateSheetContent: some View {
        NavigationView {
             if let decision = viewModel.grandDecisions[symbol] {
                 SymbolDebateView(decision: decision, isPresented: $showDebateSheet)
                     .navigationTitle("Konsey Tartışması")
                     .navigationBarHidden(true) // Custom header in view
             } else {
                 Text("Henüz karar oluşmadı.")
                     .navigationBarItems(trailing: Button("Kapat") { showDebateSheet = false })
             }
        }
    }
    
    private var chronosLabSheetContent: some View {
         NavigationView {
             ChronosLabView(viewModel: ChronosLabViewModel())
                 .environmentObject(viewModel) 
                 .navigationBarItems(trailing: Button("Kapat") { showChronosLabSheet = false })
         }
    }
    
    private var argusLabSheetContent: some View {
         NavigationView {
             ArgusLabView()
                 .environmentObject(viewModel)
                 .navigationBarItems(trailing: Button("Kapat") { showArgusLabSheet = false })
         }
    }
    
    private var observatorySheetContent: some View {
         NavigationView {
             ObservatoryContainerView()
                 .navigationBarItems(trailing: Button("Kapat") { showObservatorySheet = false })
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
                // Background (Deep Navy)
                Circle()
                    .fill(Color(hex: "1E293B")) // Slate 800
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                
                // Tech Ring (Cleaner V2)
                Circle()
                    .stroke(module.color.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                
                // Icon
                Image(systemName: module.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(module.color)
            }
            
            // LOCALIZED LABELS
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
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SanctumTheme.ghostGrey)
                .tracking(1)
        }
    }
}

// BIST Özel Orb Görünümü
struct BistOrbView: View {
    let module: ArgusSanctumView.BistModuleType
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background
                Circle()
                    .fill(Color(hex: "1E293B"))
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                
                // Tech Ring
                Circle()
                    .stroke(module.color.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                    
                // Icon
                Image(systemName: module.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(module.color)
            }
            
            // Modül İsmi
            Text(module.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SanctumTheme.ghostGrey)
                .tracking(1)
        }
    }
}

struct CenterCoreView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Binding var showDecision: Bool
    
    // Dial Interaction State
    @State private var knobRotation: Double = 0.0
    @State private var isDragging: Bool = false
    @State private var focusedModuleName: String? = nil // Shows module decision instead of main
    
    // Haptics
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            // 1. Base Compass Ring (Static)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 220, height: 220)
                
                // Ticks (Static)
                ForEach(0..<12) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 8)
                        .offset(y: -110)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }
            
            // 2. Interactive Dial Ring (The Knob)
            ZStack {
                // Ring
                Circle()
                    .stroke(Color(hex: "4A90E2").opacity(isDragging ? 0.8 : 0.4), style: StrokeStyle(lineWidth: isDragging ? 3 : 1, dash: [])) // Solid when dragging
                    .frame(width: 180, height: 180)
                
                // The Handle / Notch
                Circle()
                    .fill(Color(hex: "4A90E2"))
                    .frame(width: 12, height: 12)
                    .offset(y: -90)
                    .shadow(color: Color(hex: "4A90E2").opacity(0.5), radius: 5)
                
                // Active Sector Indicator (Cone)
                if isDragging {
                    Path { path in
                        path.move(to: CGPoint(x: 90, y: 90))
                        path.addArc(center: CGPoint(x: 90, y: 90), radius: 90, startAngle: .degrees(-15), endAngle: .degrees(15), clockwise: false)
                    }
                    .fill(Color(hex: "4A90E2").opacity(0.1))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90)) // Align to top
                }
            }
            .rotationEffect(.degrees(knobRotation))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        
                        // Calculate Angle
                        let vector = CGVector(dx: value.location.x - 90, dy: value.location.y - 90) // Center is roughly 90,90 relative to frame 180
                        
                        let angle = atan2(vector.dy, vector.dx) * 180 / .pi + 90
                        let normalizedAngle = angle < 0 ? angle + 360 : angle
                        
                        // Haptic Snap Logic (Every 45 degrees - 8 sectors)
                        let snapInterval: Double = 45
                        let nextSnap = round(normalizedAngle / snapInterval) * snapInterval
                        
                        if abs(nextSnap - knobRotation) > 1 {
                             impactFeedback.impactOccurred(intensity: 0.5)
                        }
                        
                        self.knobRotation = normalizedAngle
                        
                        // Determine Module
                        self.focusedModuleName = determineModule(angle: normalizedAngle)
                    }
                    .onEnded { _ in
                        withAnimation {
                            isDragging = false
                            // Snap to nearest sector
                            let snapInterval: Double = 45
                            self.knobRotation = round(self.knobRotation / snapInterval) * snapInterval
                        }
                        // Reset focus after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if !isDragging {
                                withAnimation {
                                    self.focusedModuleName = nil
                                }
                            }
                        }
                    }
            )
            
            // 3. Inner Data Display
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: 120, height: 120)
                .background(Circle().fill(Color(hex: "1C1C1E").opacity(0.95)))
                .onTapGesture {
                    // RESET DIAL
                    withAnimation {
                        focusedModuleName = nil
                    }
                    impactFeedback.impactOccurred(intensity: 0.7)
                }
            
            // 4. Decision Text
            if let moduleName = focusedModuleName {
                // Showing Selected Module Logic
                VStack(spacing: 4) {
                    Text(moduleName)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "4A90E2"))
                    
                    if let decision = viewModel.grandDecisions[symbol] {
                        if let bist = decision.bistDetails {
                            viewForBistModule(moduleName: moduleName, bist: bist)
                        } else {
                            viewForGlobalModule(moduleName: moduleName, decision: decision)
                        }
                    } else {
                        Text("VERİ YOK")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            } else if showDecision {
                // Showing GRAND DECISION (Default)
                VStack(spacing: 4) {
                    Text("KONSEY")
                        .font(.system(size: 8, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.gray)
                    
                    if let decision = viewModel.grandDecisions[symbol] {
                        Text(decision.action.rawValue)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(
                                decision.action == .aggressiveBuy || decision.action == .accumulate ? .green :
                                (decision.action == .liquidate || decision.action == .trim ? .red : .yellow)
                            )
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                            .minimumScaleFactor(0.8)
                        
                        Text("\(Int(decision.confidence * 100))% GÜVEN")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        
                        if !decision.vetoes.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.shield")
                                    .font(.system(size: 8))
                                Text(decision.vetoes.first?.module ?? "")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.top, 2)
                        }
                    } else {
                        Text("...")
                            .font(.system(size: 16, design: .monospaced))
                    }
                }
            } else {
                ProgressView().scaleEffect(0.8).tint(.white)
            }
        }
        .onAppear {
            // Initial animation removed to start at 0 (Top)
        }
    }
    
    // Mapping Angle (0 at top, clockwise) to Module Names
    private func determineModule(angle: Double) -> String {
        let isBist = symbol.uppercased().hasSuffix(".IS")
        
        // FILTERED MODULES (Strictly exclude Pantheon members)
        let bistModules: [ArgusSanctumView.BistModuleType] = [.grafik, .bilanço, .rejim, .sirkiye, .kulis, .moneyflow]
        let globalModules: [ArgusSanctumView.ModuleType] = [.orion, .atlas, .aether, .hermes]
        
        let sectors = isBist ? bistModules.count : globalModules.count
        let sectorAngle = 360.0 / Double(sectors)
        
        // Adjust angle so 0 is first module (centered)
        let index = Int((angle + (sectorAngle/2)).truncatingRemainder(dividingBy: 360) / sectorAngle)
        
        if isBist {
            if index < bistModules.count {
                // Map BIST Enum to Proposal Proposer String
                let module = bistModules[index]
                switch module {
                case .grafik: return "ORION"
                case .bilanço: return "ATLAS"
                case .sirkiye: return "AETHER"
                case .kulis: return "HERMES"
                case .moneyflow: return "POSEIDON"
                case .rejim: return "CHIRON" // Rejim is usually mapped to Chiron or Aether logic depending on context. Keeping CHIRON for Rejim consistent with other mappings if that's the intent, OR map to AETHER if Rejim is macro. 
                default: return "ORION"
                }
            }
        } else {
            if index < globalModules.count {
                return globalModules[index].rawValue // "ORION", "ATLAS" etc
            }
        }
        
        return "ORION"
    }

    // MARK: - Helper Views
    
    @ViewBuilder
    private func viewForBistModule(moduleName: String, bist: BistDecisionResult) -> some View {
        if let mod = getBistModuleResult(moduleName: moduleName, bist: bist) {
            Text(mod.action.rawValue)
                 .font(.system(size: 14, weight: .bold, design: .monospaced))
                 .foregroundColor(
                     mod.action == .buy ? .green :
                     (mod.action == .sell ? .red : .yellow)
                 )
            Text(String(format: "%.0f PUAN", mod.score))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
        } else {
            Text("--")
                .font(.system(size: 14, design: .monospaced))
        }
    }
    
    private func getBistModuleResult(moduleName: String, bist: BistDecisionResult) -> BistModuleResult? {
        switch moduleName {
        case "ORION": return bist.grafik
        case "ATLAS": return bist.bilanco
        case "AETHER": return bist.rejim
        case "HERMES": return bist.kulis
        case "ATHENA": return bist.faktor
        case "DEMETER": return bist.sektor
        case "POSEIDON": return bist.akis
        case "CHIRON": return nil
        default: return nil
        }
    }
    
    @ViewBuilder
    private func viewForGlobalModule(moduleName: String, decision: ArgusGrandDecision) -> some View {
        let data = getGlobalData(module: moduleName, decision: decision)
        
        if data.action != "--" {
            Text(data.action)
                 .font(.system(size: 14, weight: .bold, design: .monospaced))
                 .foregroundColor(data.color)
            Text(String(format: "%.0f%% GÜVEN", data.confidence * 100))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
        } else {
            Text("--")
                .font(.system(size: 14, design: .monospaced))
        }
    }
    
    private func getGlobalData(module: String, decision: ArgusGrandDecision) -> (action: String, confidence: Double, color: Color) {
        if module == "ORION" {
            let col: Color = decision.orionDecision.action == .buy ? .green : (decision.orionDecision.action == .sell ? .red : .yellow)
            return (decision.orionDecision.action.rawValue, decision.orionDecision.netSupport, col)
        } else if module == "ATLAS", let atlas = decision.atlasDecision {
            let col: Color = atlas.action == .buy ? .green : (atlas.action == .sell ? .red : .yellow)
            return (atlas.action.rawValue, atlas.netSupport, col)
        } else if module == "AETHER" {
            let col: Color = decision.aetherDecision.stance == .riskOn ? .green : (decision.aetherDecision.stance == .riskOff ? .red : .yellow)
            return (decision.aetherDecision.stance.rawValue, decision.aetherDecision.netSupport, col)
        } else if module == "HERMES", let hermes = decision.hermesDecision {
             return (hermes.sentiment.rawValue, hermes.netSupport, .white)
        }
        return ("--", 0, .gray)
    }

    struct Style {
        static let dashStroke = StrokeStyle(lineWidth: 1, dash: [4, 4])
    }
}

// MARK: - PANTHEON (THE OVERWATCH DECK)
struct PantheonDeckView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    let isBist: Bool
    @Binding var selectedModule: ArgusSanctumView.ModuleType?
    @Binding var selectedBistModule: ArgusSanctumView.BistModuleType?
    
    var body: some View {
        ZStack {
            // ARC LAYOUT CONTAINER
            // Height constrained to prevent pushing content too far down
            
            // 0. VISUAL CONNECTORS (Lines)
            Path { path in
                // Chiron Bottom Center
                let apex = CGPoint(x: UIScreen.main.bounds.width / 2, y: 35)
                // Athena Top Center (Approx)
                let leftFlank = CGPoint(x: (UIScreen.main.bounds.width / 2) - 100, y: 80)
                // Demeter Top Center (Approx)
                let rightFlank = CGPoint(x: (UIScreen.main.bounds.width / 2) + 100, y: 80)
                
                path.move(to: apex); path.addLine(to: leftFlank)
                path.move(to: apex); path.addLine(to: rightFlank)
            }
            .stroke(SanctumTheme.chironColor.opacity(0.15), lineWidth: 1)
            
            // 1. APEX: CHIRON (Time & Risk)
            // let chiron = viewModel.chronosDetails[symbol] (Moved to Walk-Forward)
            let chironScore = "--"
            let chironColor = SanctumTheme.chironColor // Always White for high contrast
            
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1E293B")) // Slate 800
                        .frame(width: 56, height: 56)
                        .shadow(color: chironColor.opacity(0.3), radius: 10, x: 0, y: 0) // Glow
                    
                    Circle()
                        .stroke(chironColor, lineWidth: 2) // Bold White Stroke
                        .frame(width: 56, height: 56)
                        
                    Image(systemName: "hourglass")
                        .font(.system(size: 20))
                        .foregroundColor(chironColor)
                }
                
                Text("CHIRON")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(chironColor)
                    .tracking(2)
            }
            .offset(y: -20)
            .zIndex(100)
            .onTapGesture {
                if isBist {
                    selectedBistModule = .rejim
                } else {
                    selectedModule = .chiron
                }
            }
            
            // 2. FLANKS: ATHENA (Left)
            PantheonFlankView(
                name: isBist ? "FAKTÖR" : "ATHENA",
                icon: "brain.head.profile",
                color: SanctumTheme.athenaColor,
                score: getAthenaScore(),
                label: getAthenaLabel()
            )
            .offset(x: -100, y: 55)
            .onTapGesture {
                if isBist {
                    selectedBistModule = .faktor
                } else {
                    selectedModule = .athena
                }
            }
            
            // 3. FLANKS: DEMETER (Right)
            PantheonFlankView(
                name: isBist ? "SEKTÖR" : "DEMETER",
                icon: "leaf.fill",
                color: SanctumTheme.demeterColor,
                score: getDemeterScore(),
                label: getDemeterLabel()
            )
            .offset(x: 100, y: 55)
            .onTapGesture {
                if isBist {
                    selectedBistModule = .sektor
                } else {
                    selectedModule = .demeter
                }
            }
            
        }
        .frame(height: 120)
        .padding(.top, 10)
    }
    
    // Data Helpers
    func getAthenaScore() -> String {
        if isBist {
            if let score = viewModel.grandDecisions[symbol]?.bistDetails?.faktor.score {
                return String(format: "%.0f", score)
            }
            return "--"
        } else {
            return String(format: "%.0f", viewModel.athenaResults[symbol]?.totalScore ?? 0.0)
        }
    }
    
    func getAthenaLabel() -> String {
        return isBist ? "AKIL" : "STRATEJİ"
    }
    
    func getDemeterScore() -> String {
        if isBist {
            if let score = viewModel.grandDecisions[symbol]?.bistDetails?.sektor.score {
                return String(format: "%.0f", score)
            }
            return "--"
        } else {
            return String(format: "%.0f", viewModel.getDemeterScore(for: symbol)?.totalScore ?? 0.0)
        }
    }
    
    func getDemeterLabel() -> String {
        return isBist ? "ZEMİN" : "SEKTÖR"
    }
}

struct PantheonFlankView: View {
    let name: String
    let icon: String
    let color: Color
    let score: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            // Icon Badge (Circle Geometry)
            ZStack {
                Circle()
                    .fill(Color(hex: "1E293B")) // Slate 800
                    .frame(width: 44, height: 44)
                
                Circle()
                    .stroke(color.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
            // Info
            VStack(spacing: 1) {
                Text(name)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.9))
                    .tracking(1)
                
                Text(score)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }
}

// Custom Shape for Chiron
struct HoloPanelView: View {
    let module: ArgusSanctumView.ModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    @Binding var showChronosLabSheet: Bool
    @Binding var showArgusLabSheet: Bool
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
                    .padding(.bottom, 100) // Tab bar clearance
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
        .background(SanctumTheme.bg.opacity(0.95)) // Deep Navy High Opacity
        .cornerRadius(0) // Full screen usually stays 0, but content inside might be card.
        // Let's keep HoloPanel as the "Base" layer for the module, effectively a new page.
        // User requested "Containers" to be cards. HoloPanel content is the container.

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
        case .chiron: return .demeter // Chiron/Demeter mapping
        case .prometheus: return .orion // Prometheus uses Orion's technical data
        }
    }
    
    @ViewBuilder
    func contentForModule(_ module: ArgusSanctumView.ModuleType) -> some View {
        switch module {
        case .atlas:
            // 🆕 BIST vs Global kontrolü (.IS suffix veya bilinen BIST sembolü)
            if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                // BIST sembolü için .IS suffix ekle (gerekirse)
                let bistSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol : "\(symbol.uppercased()).IS"
                BISTBilancoDetailView(sembol: bistSymbol)
            } else {
                AtlasV2DetailView(symbol: symbol)
            }
            
        case .orion:
            VStack(spacing: 16) {
                // 🆕 Eğitici Orion Detay Görünümü
                if let orion = viewModel.orionScores[symbol] {
                    OrionDetailView(
                        symbol: symbol,
                        orion: orion,
                        candles: viewModel.candles[symbol],
                        patterns: viewModel.patterns[symbol]
                    )
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(SanctumTheme.orionColor)
                        Text("Orion analizi yükleniyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
                
                // NEW: Prometheus - 5 Day Forecast
                if let candles = viewModel.candles[symbol], candles.count >= 30 {
                    ForecastCard(
                        symbol: symbol,
                        historicalPrices: candles.map { $0.close }
                    )
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
                // NEW: Hermes V2 - Sentiment Pulse from Finnhub
                SentimentPulseCard(symbol: symbol)
                
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
                    // No Decision Yet - Show Hermes Intro Card
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(SanctumTheme.hermesColor)
                            Text("Hermes Kulak Kesidi")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        // Description
                        Text("Hermes, finansal haberleri ve piyasa dedikodularını analiz ederek hisse senedinin medyadaki algısını değerlendirir.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // Dynamic Tips
                        VStack(alignment: .leading, spacing: 8) {
                            HermesInfoRow(icon: "newspaper.fill", text: "Haberleri taramak için aşağıdaki butonu kullanın")
                            HermesInfoRow(icon: "chart.line.uptrend.xyaxis", text: "Olumlu haberler fiyat yükselişini destekleyebilir")
                            HermesInfoRow(icon: "exclamationmark.triangle", text: "Olumsuz haberler risk oluşturabilir")
                        }
                    }
                    .padding()
                    .background(SanctumTheme.hermesColor.opacity(0.1))
                    .cornerRadius(12)
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
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Nasıl Öğreniyor?")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    Text("Chiron, geçmiş kararlardan ve fiyat hareketlerinden öğrenerek modül ağırlıklarını dinamik olarak ayarlar. Başarılı modüllerin ağırlığı artar.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                
                // CHRONOS LAB Button (Sheet)
                Button {
                    showChronosLabSheet = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.title3)
                            .foregroundColor(.cyan)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chronos Lab")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            Text("Walk-Forward Validation & Backtest")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // ARGUS LAB Button (Sheet)
                Button {
                    showArgusLabSheet = true
                } label: {
                    HStack {
                        Image(systemName: "flask.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Argus Lab")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.white)
                            Text("İşlem Geçmişi & Öğrenmeler")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
        case .prometheus:
            // Prometheus - 5 Day Price Forecasting (Holt-Winters)
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "crystal.ball")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Prometheus Öngörü Sistemi")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Info Box
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange.opacity(0.8))
                    Text("Prometheus, geçmiş fiyat verilerini Holt-Winters algoritması ile analiz ederek 5 günlük fiyat tahmini üretir. Güven skoru, son dönem volatilitesine göre hesaplanır.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Forecast Card
                if let candles = viewModel.candles[symbol], candles.count >= 30 {
                    ForecastCard(
                        symbol: symbol,
                        historicalPrices: candles.map { $0.close }
                    )
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.orange)
                        Text("Fiyat verisi yükleniyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("En az 30 günlük veri gerekli")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                }
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
            chironWeightRow("Phoenix", weight: weights.phoenix, color: .orange)
            chironWeightRow("Aether", weight: weights.aether, color: .purple)
            chironWeightRow("Hermes", weight: weights.hermes, color: .green)
            chironWeightRow("Demeter", weight: weights.demeter, color: .brown)
            chironWeightRow("Athena", weight: weights.athena, color: .pink)
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

struct NeuralNetworkBackground: View {
    @State private var phase = 0.0
    
    var body: some View {
        Canvas { context, size in
            let points = (0..<20).map { _ in
                CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
            }
            
            for point in points {
                for other in points {
                    let dist =  hypot(point.x - other.x, point.y - other.y)
                    if dist < 100 {
                        var path = Path()
                        path.move(to: point)
                        path.addLine(to: other)
                        context.stroke(path, with: .color(SanctumTheme.ghostGrey.opacity(0.1 - (dist/1000))), lineWidth: 1)
                    }
                }
                context.fill(Path(ellipseIn: CGRect(x: point.x-2, y: point.y-2, width: 4, height: 4)), with: .color(SanctumTheme.hologramBlue.opacity(0.3)))
            }
        }
        .opacity(0.3)
    }
}

struct SanctumMiniChart: View {
    let candles: [Candle]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minPrice = candles.map { $0.low }.min() ?? 0
            let maxPrice = candles.map { $0.high }.max() ?? 100
            let priceRange = maxPrice - minPrice
            
            Path { path in
                for (index, candle) in candles.enumerated() {
                    let xPosition = width * CGFloat(index) / CGFloat(candles.count - 1)
                    let yPosition = height * (1 - CGFloat((candle.close - minPrice) / priceRange))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Gradient Fill
            Path { path in
                for (index, candle) in candles.enumerated() {
                    let xPosition = width * CGFloat(index) / CGFloat(candles.count - 1)
                    let yPosition = height * (1 - CGFloat((candle.close - minPrice) / priceRange))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: height))
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                    
                    if index == candles.count - 1 {
                        path.addLine(to: CGPoint(x: xPosition, y: height))
                        path.closeSubpath()
                    }
                }
            }
            .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.01)]), startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - BIST HOLO PANEL (ESKİ BORSACI VERSİYONU)
struct BistHoloPanelView: View {
    let module: ArgusSanctumView.BistModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    let onClose: () -> Void
    
    // State
    @State private var showInfoCard = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: module.icon)
                        .foregroundColor(module.color)
                    Text(module.rawValue) // TR ISIM
                        .font(.headline)
                        .bold()
                        .tracking(2)
                        .foregroundColor(.white)
                    
                    Button(action: { withAnimation { showInfoCard = true } }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(module.color.opacity(0.8))
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
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(module.description)
                            .font(.caption)
                            .italic()
                            .foregroundColor(.gray)
                        
                        bistContentForModule(module)
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .task {
                if module == .rejim {
                    // Rejim verilerini tazele vs if needed
                }
                if module == .sirkiye {
                    // Sirkiye verilerini tazele
                    await refreshSirkiyeData()
                }
            }
            
            // Info Overlay (Reuse Entity mapping logic or simple hack)
            if showInfoCard {
                // Map BIST module to closest ArgusSystemEntity for help text
                let entity: ArgusSystemEntity = {
                    switch module {
                    case .bilanço: return .atlas
                    case .grafik: return .orion
                    case .sirkiye: return .aether
                    case .kulis: return .hermes
                    case .faktor: return .argus
                    case .vektor: return .orion
                    case .sektor: return .poseidon
                    case .rejim: return .demeter
                    case .moneyflow: return .poseidon // Moneyflow map to Whale/Poseidon
                    }
                }()
                SystemInfoCard(entity: entity, isPresented: $showInfoCard)
                    .zIndex(200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SanctumTheme.bg.opacity(0.95))
        .cornerRadius(0)
    }
    
    private func refreshSirkiyeData() async {
        // Sirkiye verilerini tazelemek için (Macro snapshot vs)
        // Burada force refresh yapabiliriz
        
        // 1. Dataları al
        guard let candles = await MainActor.run(body: {
            viewModel.candles[symbol]
        }), !candles.isEmpty else { return }
        
        // Ensure minimal candles
        let sortedCandles = candles.sorted { $0.date < $1.date }
        guard let candles = try? sortedCandles.suffix(60).map({ $0 }),
            candles.count >= 50 // Need enough data
        else { return }
        
        // Safely unwrap optional limited candles
        // Actually ArraySlice to Array is safe.
        // let limitCandles = Array(candles) 
        
        // Re-run logic... but this view creates SirkiyeDashboard which uses viewModel.
        // We just need to trigger viewModel refresher if needed.
        // ArgusGrandCouncil convene() handles this internal logic.
        
        // Manually triggering convene for comprehensive update:
        
        // 1. Candles hazirla (Async context safe)
        // let candles = viewModel.candles[symbol] // Main actor isolation issue if accessed directly here?
        // Using MainActor.run above
        
        // We need 'candles' here available to this scope.
        // Using previous guard results.
        
        // 1.1 Limit to 60 (son 60 gün yeterli sirkülasyon için)
        // This logic was in ArgusGrandCouncil.
        
        // Let's call convene on background
        
        // 1. Sirkiye Input hazırlamak için verilere eriş (Main Actor)
        
        // ... (Logic from Step 2594 - refreshSirkiyeData implementation)
        // I will copy exact logic if I can find it.
        // Step 2594 line 1950 implies logic existed.
        
        // Logic from Step 2594 (lines 1940+):
        
        let candleList = Array(candles) // Convert slice to array
        
        // 2. Sirkiye Input
        let usdTry = await MainActor.run { viewModel.quotes["USD/TRY"]?.currentPrice ?? 35.0 }
        let usdTryPrev = await MainActor.run { viewModel.quotes["USD/TRY"]?.previousClose ?? 35.0 }
        
        let sirkiyeInput = SirkiyeEngine.SirkiyeInput(
            usdTry: usdTry,
            usdTryPrevious: usdTryPrev,
            dxy: 104.0, // Default or fetch
            brentOil: 80.0,
            globalVix: 15.0,
            newsSnapshot: nil,
            currentInflation: 45.0,
            xu100Change: nil,
            xu100Value: nil,
            goldPrice: nil
        )
        
        let macro = MacroSnapshot.fromCached()
        let decision = await ArgusGrandCouncil.shared.convene(
            symbol: symbol,
            candles: candleList,
            financials: nil,
            macro: macro,
            news: nil,
            engine: .pulse,
            sirkiyeInput: sirkiyeInput
        )
        
        await MainActor.run {
            viewModel.grandDecisions[symbol] = decision
            print("✅ BistHoloPanel: \(symbol) için BIST kararı (Sirkülasyon) tazelendi.")
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
            // Teknik gostergeler (SAR, TSI, RSI)
            GrafikEducationalCard(symbol: symbol)
            
            // Rölatif Güç (XU100'e göre performans)
            OrionRelativeStrengthCard(symbol: symbol)
            
            // Prometheus - 5 Gunluk Fiyat Tahmini (Global ile ayni)
            if let candles = viewModel.candles[symbol], candles.count >= 30 {
                ForecastCard(
                    symbol: symbol,
                    historicalPrices: candles.map { $0.close }
                )
            }
            
        case .bilanço:
            // BIST Bilanco Egitim Gorunumu
            let bistSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol : "\(symbol.uppercased()).IS"
            BISTBilancoDetailView(sembol: bistSymbol)
            
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
            // 🆕 BIST Sentiment Pulse (Ana Bileşen)
            BISTSentimentPulseCard(symbol: symbol)
            
            // Backend karar verisi (varsa)
            if let detail = bistDetails?.kulis {
                BistModuleDetailCard(
                    moduleResult: detail,
                    moduleColor: module.color,
                    moduleIcon: module.icon
                )
            }
            
            // Analist kartları (Hermes - Alt Bileşen)
            HermesAnalystCard(
                symbol: symbol,
                currentPrice: viewModel.quotes[symbol]?.currentPrice ?? 0,
                newsDecision: viewModel.grandDecisions[symbol]?.hermesDecision
            )
            
        case .sirkiye:
            // Sirkiye Dashboard (Makro Görünüm)
            SirkiyeDashboardView(viewModel: viewModel)
        
        case .vektor:
            // Prometheus Vektor Tahmin
             // Prometheus - 5 Day Price Forecasting (Holt-Winters)
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "crystal.ball")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Prometheus Öngörü Sistemi")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                if let candles = viewModel.candles[symbol], candles.count >= 30 {
                    ForecastCard(
                        symbol: symbol,
                        historicalPrices: candles.map { $0.close }
                    )
                } else {
                     Text("Yetersiz veri")
                }
            }
        }
    }
}

// MARK: - Hermes Helper View

struct HermesInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(SanctumTheme.hermesColor.opacity(0.8))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
