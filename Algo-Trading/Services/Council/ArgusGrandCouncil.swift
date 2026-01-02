import Foundation

// MARK: - Argus V3 Action Types
enum ArgusAction: String, Sendable, Codable {
    case aggressiveBuy = "🚀 HÜCUM"             // Güçlü Alım
    case accumulate = "📈 BİRİKTİR"             // Kademeli Alım
    case neutral = "⏸️ GÖZLE"                   // Bekle / Tut
    case trim = "📉 AZALT"                      // Satış (Kâr Al)
    case liquidate = "⛔ ÇIK"                   // Tam Çıkış (Stop)
    
    var colorName: String {
        switch self {
        case .aggressiveBuy: return "Green"
        case .accumulate: return "Blue"
        case .neutral: return "Gray"
        case .trim: return "Orange"
        case .liquidate: return "Red"
        }
    }
}

enum SignalStrength: String, Sendable, Codable {
    case strong = "GÜÇLÜ"
    case normal = "NORMAL"
    case weak = "ZAYIF"
    case vetoed = "VETOLANDI"
}

struct ArgusGrandDecision: Sendable, Equatable, Codable {
    let id: UUID
    let symbol: String
    let action: ArgusAction
    let strength: SignalStrength
    let confidence: Double
    let reasoning: String
    
    // Details
    let contributors: [ModuleContribution]
    let vetoes: [ModuleVeto]
    
    // Non-voting Advisors (Educational)
    var advisors: [AdvisorNote] = []
    
    // Individual council decisions (Snapshot for UI)
    let orionDecision: CouncilDecision
    let atlasDecision: AtlasDecision?
    let aetherDecision: AetherDecision
    let hermesDecision: HermesDecision?
    
    // For Information Quality UI
    let moduleWeights: InformationWeights? = nil
    
    // For Phoenix
    let phoenixAdvice: PhoenixAdvice? = nil
    let cronosScore: Double? = nil
    
    // Rich Data for Voice/UI
    let orionDetails: OrionScoreResult?
    let financialDetails: FinancialSnapshot?
    
    let timestamp: Date
    
    var shouldTrade: Bool {
        return action == .aggressiveBuy || action == .accumulate || action == .trim || action == .liquidate
    }
    
    static func == (lhs: ArgusGrandDecision, rhs: ArgusGrandDecision) -> Bool {
        return lhs.id == rhs.id
    }
}


    
extension ArgusGrandDecision {
    // Recommended Allocation Multiplier based on Action
    var allocationMultiplier: Double {
        switch action {
        case .aggressiveBuy: return 1.0  // 100% of max allocation
        case .accumulate: return 0.3     // 30% start
        case .neutral: return 0.0
        case .trim: return 0.5          // Sell 50%
        case .liquidate: return 1.0     // Sell 100%
        }
    }
}


// MARK: - Argus Grand Council
/// The Supreme Council - combines all module decisions for the final verdict
actor ArgusGrandCouncil {
    static let shared = ArgusGrandCouncil()
    
    // MARK: - Cache
    private var decisionCache: [String: (decision: ArgusGrandDecision, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 Minutes
    
    // MARK: - Public API
    
    /// Main entry point: Gather all councils and make the grand decision
    /// Uses caching to prevent unnecessary re-calculation
    func convene(
        symbol: String,
        candles: [Candle],
        financials: FinancialsData?,
        macro: MacroSnapshot,
        news: HermesNewsSnapshot?,
        engine: AutoPilotEngine,
        athena: AthenaFactorResult? = nil,
        demeter: DemeterScore? = nil,
        chiron: ChronosResult? = nil,
        // NEW: BIST Macro Input (Sirkiye)
        sirkiyeInput: SirkiyeEngine.SirkiyeInput? = nil,
        forceRefresh: Bool = false
    ) async -> ArgusGrandDecision {
        
        // 1. Check Cache
        if !forceRefresh, let cached = decisionCache[symbol] {
             if Date().timeIntervalSince(cached.timestamp) < cacheTTL {
                 print("🏛️ Argus: Cache kullanılıyor (\(symbol))")
                 return cached.decision
             }
         }
        
        let timestamp = Date()
        print("🏛️🏛️🏛️ ARGUS ÜST KONSEYİ TOPLANIYOR: \(symbol)")
        print("=".padding(toLength: 50, withPad: "=", startingAt: 0))
        
        let isBist = symbol.uppercased().hasSuffix(".IS")
        
        // 2. Gather all council decisions (Parallel execution could be optimized here)
        let orionDecision: CouncilDecision
        
        if isBist {
            print("🇹🇷 Orion TR (Turquoise) Devrede - \(symbol)")
            orionDecision = await OrionBistEngine.shared.analyze(symbol: symbol, candles: candles)
        } else {
            orionDecision = await OrionCouncil.shared.convene(symbol: symbol, candles: candles, engine: engine)
        }
        
        var atlasDecision: AtlasDecision? = nil
        if let fin = financials {
            // Map FinancialsData to FinancialSnapshot for Atlas
            let snapshot = FinancialSnapshot(
                symbol: fin.symbol,
                marketCap: fin.marketCap,
                price: 0.0, // Price fetched separately
                peRatio: fin.peRatio,
                forwardPE: fin.forwardPERatio,
                pbRatio: fin.priceToBook,
                psRatio: fin.priceToSales,
                evToEbitda: fin.evToEbitda,
                revenueGrowth: fin.revenueGrowth,
                earningsGrowth: fin.earningsGrowth,
                epsGrowth: nil,
                roe: fin.returnOnEquity,
                roa: fin.returnOnAssets,
                debtToEquity: fin.debtToEquity,
                currentRatio: fin.currentRatio,
                grossMargin: fin.grossMargin,
                operatingMargin: fin.operatingMargin,
                netMargin: fin.profitMargin,
                dividendYield: fin.dividendYield,
                payoutRatio: nil,
                dividendGrowth: nil,
                beta: nil,
                sharesOutstanding: nil,
                floatShares: nil,
                insiderOwnership: nil,
                institutionalOwnership: nil,
                sectorPE: nil,
                sectorPB: nil,
                targetMeanPrice: nil,
                targetHighPrice: nil,
                targetLowPrice: nil,
                recommendationMean: nil,
                analystCount: nil
            )
            
            if isBist {
                print("🇹🇷 Atlas TR (Turquoise) Devrede - \(symbol)")
                atlasDecision = await AtlasBistEngine.shared.analyze(symbol: symbol, financials: snapshot)
            } else {
                atlasDecision = await AtlasCouncil.shared.convene(symbol: symbol, financials: snapshot, engine: engine)
            }
        }
        
        // 3. Aether (Macro) - Project Turquoise Integration (Sirkiye)
        let aetherDecision: AetherDecision
        
        if isBist, let bistInput = sirkiyeInput {
            print("🇹🇷 Sirkiye (Politik Korteks) Devrede - \(symbol)")
            aetherDecision = await SirkiyeEngine.shared.analyze(input: bistInput)
        } else {
            aetherDecision = await AetherCouncil.shared.convene(macro: macro)
        }
        
        var hermesDecision: HermesDecision? = nil
        if let newsData = news {
            hermesDecision = await HermesCouncil.shared.convene(symbol: symbol, news: newsData)
        }
        
        // 2.5 Get Weights (Non-blocking now)
        let weights = ChironCouncilLearningService.shared.getCouncilWeights(symbol: symbol, engine: engine)
        
        // 3. Calculate grand decision
        let grandDecision = calculateGrandDecision(
            symbol: symbol,
            orion: orionDecision,
            atlas: atlasDecision,
            aether: aetherDecision,
            hermes: hermesDecision,
            engine: engine,
            weights: weights,
            // Rich Data context
            orionDetails: OrionAnalysisService.shared.calculateOrionScore(symbol: symbol, candles: candles, spyCandles: nil),
            financialDetails: atlasDecision != nil ? FinancialSnapshot(
                symbol: symbol,
                marketCap: financials?.marketCap,
                price: candles.last?.close ?? 0.0,
                peRatio: financials?.peRatio,
                forwardPE: financials?.forwardPERatio,
                pbRatio: financials?.priceToBook,
                psRatio: financials?.priceToSales,
                evToEbitda: financials?.evToEbitda,
                revenueGrowth: financials?.revenueGrowth,
                earningsGrowth: financials?.earningsGrowth,
                epsGrowth: nil,
                roe: financials?.returnOnEquity,
                roa: financials?.returnOnAssets,
                debtToEquity: financials?.debtToEquity,
                currentRatio: financials?.currentRatio,
                grossMargin: financials?.grossMargin,
                operatingMargin: financials?.operatingMargin,
                netMargin: financials?.profitMargin,
                dividendYield: financials?.dividendYield,
                payoutRatio: nil,
                dividendGrowth: nil,
                beta: nil,
                sharesOutstanding: nil,
                floatShares: nil,
                insiderOwnership: nil,
                institutionalOwnership: nil,
                sectorPE: nil,
                sectorPB: nil,
                targetMeanPrice: nil,
                targetHighPrice: nil,
                targetLowPrice: nil,
                recommendationMean: nil,
                analystCount: nil
            ) : nil,
            // Advisors
            athena: athena,
            demeter: demeter,
            chiron: chiron
        )
        
        // 4. Update Cache
        decisionCache[symbol] = (grandDecision, Date())
        
        // 5. Notify Learning Service
        Task {
            let record = CouncilVotingRecord(
                id: UUID(),
                symbol: symbol,
                engine: engine,
                timestamp: timestamp,
                proposerId: "orion_master",
                action: orionDecision.action.rawValue,
                approvers: grandDecision.contributors.map { $0.module.lowercased() },
                vetoers: grandDecision.vetoes.map { $0.module.lowercased() },
                abstainers: [],
                finalDecision: grandDecision.action.rawValue,
                netSupport: 0.0,
                outcome: nil,
                pnlPercent: nil
            )
            await ChironCouncilLearningService.shared.recordDecision(record)
        }
        
        return grandDecision
    }
    
    // MARK: - Core Logic: The V3 Verdict Mechanism
    
    private func calculateGrandDecision(
        symbol: String,
        orion: CouncilDecision,
        atlas: AtlasDecision?,
        aether: AetherDecision,
        hermes: HermesDecision?,
        engine: AutoPilotEngine,
        weights: CouncilMemberWeights,
        // Details
        orionDetails: OrionScoreResult?,
        financialDetails: FinancialSnapshot?,
        // Advisors
        athena: AthenaFactorResult?,
        demeter: DemeterScore?,
        chiron: ChronosResult?
    ) -> ArgusGrandDecision {
        
        var contributors: [ModuleContribution] = []
        var vetoes: [ModuleVeto] = []
        var advisorNotes: [AdvisorNote] = []
        
        // --- ADVISORS ---
        advisorNotes.append(CouncilAdvisorGenerator.generateAthenaAdvice(result: athena))
        advisorNotes.append(CouncilAdvisorGenerator.generateDemeterAdvice(score: demeter))
        
        // Calculate temp action for Chiron check (simplified, will refine later if needed)
        let _ = orion.action 
        advisorNotes.append(CouncilAdvisorGenerator.generateChironAdvice(result: chiron, action: .neutral))

        
        // --- 1. ORION (Technical) ---
        let isStrongOrion = orion.action == .buy && orion.netSupport > 0.7
        let isOrionSell = orion.action == .sell
        
        contributors.append(ModuleContribution(
            module: "Orion",
            action: orion.action,
            confidence: orion.netSupport,
            reasoning: "Teknik: \(orion.action.rawValue)"
        ))
        
        if isOrionSell {
            // Can be treated as advice, not strict veto unless we are buying
        }
        
        // --- 2. ATLAS (Fundamental) ---
        if let atlas = atlas {
            let _ = atlas.action == .buy && atlas.netSupport > 0.7
            let isAtlasSell = atlas.action == .sell
            
            contributors.append(ModuleContribution(
                module: "Atlas",
                action: atlas.action,
                confidence: atlas.netSupport,
                reasoning: "Temel: \(atlas.action.rawValue)"
            ))
            
            if isAtlasSell {
                vetoes.append(ModuleVeto(module: "Atlas", reason: "Finansal Yapı Zayıf"))
            }
        }
        
        // --- 3. AETHER (Macro) ---
        // Using 'marketMode' and 'stance' (riskOn/riskOff)
        
        let isRiskOff = aether.stance == .riskOff
        let isCrash = aether.marketMode == .panic || aether.marketMode == .fear
        
        // Aether ALWAYS contributes - determine action based on stance
        let aetherAction: ProposedAction
        switch aether.stance {
        case .riskOn:
            aetherAction = .buy
        case .cautious, .defensive:
            aetherAction = .hold
        case .riskOff:
            aetherAction = .sell
        }
        
        contributors.append(ModuleContribution(
            module: "Aether",
            action: aetherAction,
            confidence: aether.netSupport,
            reasoning: "Makro Rejim: \(aether.stance.rawValue)"
        ))
        
        if isRiskOff || isCrash {
            vetoes.append(ModuleVeto(module: "Aether", reason: "Makro Ortam: \(aether.marketMode.rawValue)"))
        }
        
        // --- 4. HERMES (News) ---
        if let hermes = hermes {
            // Determine action based on sentiment
            let hermesAction: ProposedAction
            let sentimentStr = "\(hermes.sentiment)"
            let isPositive = sentimentStr.lowercased().contains("positive")
            let isNegative = sentimentStr.lowercased().contains("negative")
            
            if isPositive {
                hermesAction = .buy
            } else if isNegative {
                hermesAction = .sell
            } else {
                hermesAction = .hold
            }
            
            // Hermes ALWAYS contributes when data exists
            contributors.append(ModuleContribution(
                module: "Hermes",
                action: hermesAction,
                confidence: hermes.netSupport,
                reasoning: "Haber: \(hermes.sentiment.rawValue)"
            ))
            
            // Still veto on high-impact negative
            if isNegative && hermes.isHighImpact {
                vetoes.append(ModuleVeto(module: "Hermes", reason: "Kötü Haber Akışı"))
            }
        }
        
        // --- DECISION LOGIC V3 ---
        
        var finalAction: ArgusAction = .neutral
        var strength: SignalStrength = .normal
        var reasoning = ""
        
        // Veto Check
        if !vetoes.isEmpty {
            if isOrionSell {
                finalAction = .liquidate
                reasoning = "Kritik Satış Sinyali ve Konsey Vetosu."
                strength = .strong
            } else {
                finalAction = .neutral
                strength = .vetoed
                reasoning = "Alım sinyali Konsey tarafından veto edildi: \(vetoes.first?.reason ?? "")"
            }
        } else {
            // No Vetoes - Clean Path
            
            switch orion.action {
            case .buy:
                // Check synergy: Atlas or Aether support
                let synergy = (atlas?.action == .buy) || (aether.stance == .riskOn)
                
                if isStrongOrion && synergy {
                    finalAction = .aggressiveBuy
                    strength = .strong
                    reasoning = "Teknik ve Temel/Makro Uyumda. Tam Güç."
                } else {
                    finalAction = .accumulate
                    strength = .normal
                    reasoning = "Teknik olumlu, kademeli giriş."
                }
                
            case .hold:
                finalAction = .neutral
                reasoning = "Mevcut pozisyon korunmalı."
                
            case .sell:
                finalAction = .trim
                reasoning = "Trend zayıflıyor, kar alma zamanı."
            }
        }
        
        // Apply Aether Warning to Buy Actions
        if (finalAction == .aggressiveBuy || finalAction == .accumulate) && (aether.marketMode == .fear) {
            finalAction = .accumulate // Don't go aggressive in fear
            reasoning += " (Makro korku nedeniyle baskılandı)"
        }
        
        return ArgusGrandDecision(
            id: UUID(),
            symbol: symbol,
            action: finalAction,
            strength: strength,
            confidence: orion.netSupport, // Base confidence on technicals
            reasoning: reasoning,
            contributors: contributors,
            vetoes: vetoes,
            advisors: advisorNotes,
            orionDecision: orion,
            atlasDecision: atlas,
            aetherDecision: aether,
            hermesDecision: hermes,
            orionDetails: orionDetails,
            financialDetails: financialDetails,
            timestamp: Date()
        )
    }
}

// Supporting Structs
struct ModuleContribution: Sendable, Equatable, Codable {
    let module: String
    let action: ProposedAction
    let confidence: Double
    let reasoning: String
}

struct ModuleVeto: Sendable, Equatable, Codable {
    let module: String
    let reason: String
}

// Placeholder for Information Weights if not found
struct InformationWeights: Codable, Sendable {
    let orion: Double
    let atlas: Double
    let aether: Double
}
