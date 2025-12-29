import Foundation

// MARK: - Enums
// MARK: - Enums
// SignalAction moved to HeimdallTypes.swift

struct ScoutLog: Identifiable, Sendable {
    let id = UUID()
    let symbol: String
    let status: String // "ONAYLI", "RED", "BEKLE"
    let reason: String
    let score: Double
    let timestamp: Date = Date()
}

// MARK: - System Education Model
enum ArgusSystemEntity: String, CaseIterable, Identifiable {
    case argus = "Argus"
    case aether = "Aether"
    case orion = "Orion"
    case chronos = "Chronos"
    case atlas = "Atlas"
    case hermes = "Hermes"
    case poseidon = "Poseidon"
    case corse = "Corse"
    case pulse = "Pulse"
    case shield = "Shield"
    case council = "Konsey"
    
    var id: String { rawValue }
    
    var color: String { // Returning hex or system name string for easier mapping if needed, but returning generic names is safer for View usage if we extend Theme
        switch self {
        case .argus: return "Blue"
        case .aether: return "Cyan"
        case .orion: return "Purple"
        case .chronos: return "Orange"
        case .atlas: return "Indigo"
        case .hermes: return "Pink"
        case .poseidon: return "Teal"
        case .corse: return "Blue"
        case .pulse: return "Purple"
        case .shield: return "Green"
        case .council: return "Gold"
        }
    }
    
    var icon: String {
        switch self {
        case .argus: return "eye.trianglebadge.exclamationmark.fill"
        case .aether: return "cloud.fog.fill"
        case .orion: return "scope"
        case .chronos: return "clock.arrow.circlepath"
        case .atlas: return "globe.europe.africa.fill"
        case .hermes: return "newspaper.fill"
        case .poseidon: return "drop.triangle.fill" // Whale/Sea
        case .corse: return "tortoise.fill"
        case .pulse: return "bolt.heart.fill"
        case .shield: return "shield.fill"
        case .council: return "building.columns.fill"
        }
    }
    
    var description: String {
        switch self {
        case .argus:
            return "Sistemin beyni; Tüm verileri gören dev. Temel analiz, haber akışı ve makro verileri birleştirerek 'Ne almalı?' sorusuna yanıt arar. Asla uyumaz."
        case .aether:
            return "Piyasa Atmosferi; Makroekonomik iklimi (VIX, Faizler, DXY) koklar. Fırtına yaklaşıyorsa risk iştahını kapatır. 'Ne zaman almalı?' sorusunun cevabıdır."
        case .orion:
            return "Avcı; Teknik analizin ustasıdır. Trendleri, formasyonları ve momentumu hesaplar. Fiyatın 'Nereden alınmalı?' olduğunu belirler. Keskin nişancıdır."
        case .chronos:
            return "Zaman Yolcusu; Geçmiş veriler üzerinde stratejileri test eder (Backtest). 'Tarih tekerrür eder mi?' sorusunu yanıtlar. Geleceği öngörmek için geçmişe bakar."
        case .atlas:
            return "Değerleme Uzmanı; Şirketlerin bilançolarını, nakit akışlarını ve adil değerini hesaplar. Fiyat etiketinin ötesindeki gerçek değeri bulur."
        case .hermes:
            return "Haberci; Sosyal medya, kap bildirimleri ve flaş haberleri ışık hızında tarar. Fiyat hareketinden önce bilgiyi size ulaştırır."
        case .poseidon:
            return "Balina Dedektifi; Derin sulardaki büyük oyuncuların (kurumsal fonlar, balinalar) hareketlerini izler. Büyük para nereye akarsa oraya yönelir."
        case .corse:
            return "Dayanıklılık Motoru (Swing); Sakin ve sabırlı. Pozisyonları günler/haftalar boyunca taşır. Trend takibi yapar. Stres seviyesi düşüktür."
        case .pulse:
            return "Nabız Motoru (Scalp); Yüksek adrenalin. Dakikalar hatta saniyeler süren işlemleri hedefler. Küçük fiyat hareketlerinden kar çıkarmaya çalışır."
        case .shield:
            return "Kalkan; Portföyü koruyan savunma mekanizması. İşler ters giderse devreye girer, stop-loss çalıştırır veya hedge pozisyonu açar."
        case .council:
            return "Konsey (Agora); Karar Merkezi. Tüm tanrıların (modüllerin) oylarını toplar, çelişkileri çözer ve nihai AL/SAT kararını verir. Demokrasi ile yönetilen yapay zeka."
        }
    }
}

// MARK: - Macro Models
// ----------------------------------------------------------------
struct MacroData: Codable, Sendable {
    let vix: Double
    let bond10y: Double
    let bond2y: Double
    let dxy: Double
    let date: Date
}

struct Candle: Identifiable, Codable, @unchecked Sendable, Equatable {
    var id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    
    enum CodingKeys: String, CodingKey {
        case date, open, high, low, close, volume
    }
    
    // Demo Helper
    static func generateMockCandles(count: Int, startPrice: Double) -> [Candle] {
        var candles: [Candle] = []
        var currentPrice = startPrice
        let now = Date()
        
        for i in 0..<count {
            // Random walk
            let change = Double.random(in: -2.0...2.5)
            let open = currentPrice
            let close = open + change
            let high = max(open, close) + Double.random(in: 0.0...1.0)
            let low = min(open, close) - Double.random(in: 0.0...1.0)
            let volume = Double.random(in: 1_000_000...10_000_000)
            
            // Reverse date
            let date = Calendar.current.date(byAdding: .day, value: -(count - 1 - i), to: now)!
            
            candles.append(Candle(
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            ))
            
            currentPrice = close
        }
        
        return candles
    }
}

struct Quote: Codable, Sendable {
    let c: Double // Current
    var d: Double? // Change (Raw/Optional)
    var dp: Double? // Percent Change (Raw/Optional)
    let currency: String?
    var shortName: String? = nil
    var symbol: String? = nil
    
    // Recovery Field
    var previousClose: Double? = nil
    
    // New Optional Fields
    var volume: Double? = nil
    var marketCap: Double? = nil
    var peRatio: Double? = nil
    var eps: Double? = nil
    var sector: String? = nil
    
    var currentPrice: Double { return c }
    
    // Computed Change Logic
    var change: Double {
        if let val = d, val != 0 { return val }
        guard let prev = previousClose, prev > 0 else { return 0.0 }
        return c - prev
    }
    
    var percentChange: Double {
        if let val = dp, val != 0 { return val }
        guard let prev = previousClose, prev > 0 else { return 0.0 }
        return ((c - prev) / prev) * 100.0
    }
    
    var isPositive: Bool { change >= 0 }
    
    // Phase 3: Staleness Guard
    var timestamp: Date? = nil
}

enum DataError: Error {
    case staleData
    case insufficientHistory
    case noData
}

struct CompositeScore: Identifiable {
    let id = UUID()
    let totalScore: Double // -100 to +100
    let breakdown: [String: Double] // e.g., "RSI": -20, "Trend": +50
    let sentiment: SignalAction // Derived from totalScore
    
    var colorName: String {
        if totalScore >= 50 { return "Green" }
        else if totalScore <= -50 { return "Red" }
        else { return "Gray" }
    }
}

struct Signal: Identifiable {
    let id = UUID()
    let strategyName: String
    let action: SignalAction
    let confidence: Double // 0.0 - 100.0
    let reason: String
    let indicatorValues: [String: String] // e.g. "RSI": "32.5"
    
    // V6: Education Module
    let logic: String // "How it works"
    let successContext: String // "Where it works best"
    let simplifiedExplanation: String // New: Detailed but simple explanation
    
    let date: Date = Date()
}

enum TradeSource: String, Codable {
    case user = "USER"
    case autoPilot = "AUTO_PILOT"
}

enum AutoPilotEngine: String, Codable {
    case corse = "CORSE" // Swing / Mid-Term
    case pulse = "PULSE" // Scalp / News / Short-Term
    case shield = "SHIELD" // Hedge / Defense
    case hermes = "HERMES" // News Discovery
    case manual = "MANUAL"
}

// MARK: - Auto Pilot Signals
struct TradeSignal {
    let symbol: String
    let action: SignalAction
    let reason: String
    let confidence: Double
    let timestamp: Date
    let stopLoss: Double?
    let takeProfit: Double?
    var trimPercentage: Double? = nil // Support for Partial Sells (Active Trim)
}

struct Trade: Identifiable, Codable {
    var id = UUID()
    let symbol: String
    let entryPrice: Double
    var quantity: Double // Spot Precision (Fractional shares supported)
    let entryDate: Date
    var isOpen: Bool
    var exitPrice: Double?
    var exitDate: Date?
    var source: TradeSource = .user
    var engine: AutoPilotEngine? // Corse or Pulse
    
    // Auto-Pilot Details
    // Auto-Pilot Details
    var stopLoss: Double?
    var takeProfit: Double? // (Optional, usually dynamic now)
    var highWaterMark: Double? // Highest price seen since entry (For Trailing Stop)
    var rationale: String?
    var voiceReport: String? // Cached Argus Voice Report
    var decisionContext: DecisionContext? // Snapshot of the decision (Why/How/Who)
    var agoraTrace: AgoraTrace? // AGORA V2 Trace
    
    var profit: Double {
        guard let exit = exitPrice else { return 0.0 }
        let diff = exit - entryPrice
        return diff * quantity
    }
    
    var profitPercentage: Double {
        guard let exit = exitPrice else { return 0.0 }
        guard entryPrice > 0 else { return 0.0 } // Safety
        return ((exit - entryPrice) / entryPrice) * 100.0
    }
}

// MARK: - Safe Universe Models

struct SafeAsset: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let type: SafeAssetType
    let expenseRatio: Double
}

struct MarketCategory: Identifiable {
    let id = UUID()
    let title: String
    let symbols: [String]
}

// MARK: - Transaction History
enum TransactionType: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    case attempt = "ATTEMPT" // NEW: Blocked trades
}

// MARK: - Export Snapshots (Enriched Data)

struct DecisionTraceSnapshot: Codable {
    let mode: String // CORSE, PULSE
    let overallScore: Double?
    let scores: ScoresSnapshot
    let thresholds: ThresholdsSnapshot
    let reasonsTop3: [ReasonSnapshot]
    let guards: GuardsSnapshot
    let blockReason: String?
    let phoenix: PhoenixSnapshot? // Schema V2
    let standardizedOutputs: [String: StandardModuleOutput]? // Export V2
    
    struct ScoresSnapshot: Codable {
        let atlas: Double?
        let orion: Double?
        let aether: Double?
        let hermes: Double?
        let demeter: Double?
    }
    struct ThresholdsSnapshot: Codable {
        let buyOverallMin: Double?
        let sellOverallMin: Double?
        let orionMin: Double?
        let atlasMin: Double?
        let aetherMin: Double?
        let hermesMin: Double?
    }
    struct ReasonSnapshot: Codable {
        let key: String
        let value: Double?
        let note: String
    }
    struct GuardsSnapshot: Codable {
        let cooldownActive: Bool
        let minHoldBlocked: Bool
        let minMoveBlocked: Bool
        let costGateBlocked: Bool
        let rebalanceBandBlocked: Bool
        let rateLimitBlocked: Bool
        let otherBlocked: Bool
    }
}

struct MarketSnapshot: Codable {
    let bid: Double?
    let ask: Double?
    let spreadPct: Double?
    let atr: Double?
    let returns: ReturnsSnapshot

    let barsSummary: BarsSummarySnapshot
    // Schema V2
    let barTimestamp: Date?
    let signalPrice: Double?
    let volatilityHint: Double?
    
    struct ReturnsSnapshot: Codable {
        let r1m: Double?
        let r5m: Double?
        let r1h: Double?
        let r1d: Double?
        let rangePct: Double?
        let gapPct: Double?
    }
    struct BarsSummarySnapshot: Codable {
        let lookback: Int
        let high: Double?
        let low: Double?
        let close: Double?
    }
}

struct PositionSnapshot: Codable {
    let positionQtyBefore: Double?
    let positionQtyAfter: Double?
    let avgCostBefore: Double?
    let avgCostAfter: Double?
    let holdingSeconds: Double?
    let unrealizedPnlBefore: Double?
    let realizedPnlThisTrade: Double?
    let portfolioSnapshot: PortfolioSnapshot?
    
    struct PortfolioSnapshot: Codable {
        let cashBefore: Double?
        let cashAfter: Double?
        let grossExposure: Double?
        let netExposure: Double?
        let positionsCount: Int?
    }
}

struct ExecutionSnapshot: Codable {
    let orderType: String // MARKET, LIMIT
    let requestedPrice: Double?
    let filledPrice: Double?
    let slippagePct: Double?
    let latencyMs: Double?
    let partialFill: Bool?
    // Schema V2
    let requestedQty: Double?
    let filledQty: Double?
    let venue: String?
}

struct OutcomeLabels: Codable {
    var pnlAfter1h: Double?
    var pnlAfter1d: Double?
    var mfePct: Double?
    var mddPct: Double?
    var flipWithin1h: Bool?
    var flipWithin1d: Bool?
    var label: String? // GOOD, BAD, NEUTRAL
    var labelHorizon: String?
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    let type: TransactionType
    let symbol: String
    let amount: Double // Total Value
    let price: Double
    let date: Date
    var fee: Double? // Midas Fee etc.
    
    // PnL Data
    var pnl: Double?
    var pnlPercent: Double?
    
    // Enriched Data (Argus v2 Export)
    var decisionTrace: DecisionTraceSnapshot?
    var marketSnapshot: MarketSnapshot?
    var positionSnapshot: PositionSnapshot?
    var execution: ExecutionSnapshot?
    var outcome: OutcomeLabels?
    
    // Schema V2 Extensions
    var schemaVersion: Int?
    var source: String? // AUTOPILOT / MANUAL
    var strategy: String? // CORSE / PULSE
    var reasonCode: String?
    var decisionContext: DecisionContext?
    
    // Churn
    var cooldownUntil: Date?
    var minHoldUntil: Date?
    var guardrailHit: Bool?
    var guardrailReason: String?
    
    // Idempotency (ID V2)
    var decisionId: String? // Linked from DecisionSnapshot
    var intentId: String? // Unique ID for this specific trade attempt
}

// MARK: - Schema V2 Structs
struct DecisionContext: Codable {
    let decisionId: String
    let overallAction: String
    let dominantSignals: [String]
    let conflicts: [DecisionConflict]
    let moduleVotes: ModuleVotes
}

struct DecisionConflict: Codable {
    let moduleA: String
    let moduleB: String
    let topic: String
    let severity: Double
}

struct ModuleVotes: Codable {
    let atlas: ModuleVote?
    let orion: ModuleVote?
    let aether: ModuleVote?
    let hermes: ModuleVote?
    let chiron: ModuleVote?
}

struct ModuleVote: Codable {
    let score: Double
    let direction: String
    let confidence: Double
}

// MARK: - Settings Models

struct LegalDocument: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct Certificate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}



// MARK: - Missing Snapshots (Fixing Compilation)

struct PhoenixSnapshot: Codable {
    let timeframe: String
    let activeSignal: Bool
    let confidence: Double
    let lowerBand: Double
    let upperBand: Double
    let midLine: Double
    let distanceToLow: Double?
}

// MARK: - Snapshot Helpers
struct SnapshotEvidence: Codable, Sendable {
    let module: String
    let claim: String
    let confidence: Double
    let direction: String
}

struct SnapshotRiskContext: Codable, Sendable {
    let regime: String
    let aetherScore: Double
    let chironState: String
}

struct DecisionSnapshot: Codable {
    // Identity
    let id: UUID
    let symbol: String
    let timestamp: Date
    
    // Core Decision
    let action: SignalAction
    let overallScore: Double
    let reason: String
    let confidence: Double
    
    // Detailed Context (Required for Audit/Trace)
    let evidence: [SnapshotEvidence]
    let riskContext: SnapshotRiskContext? 
    let dominantSignals: [String]
    let conflicts: [DecisionConflict]
    
    // Agora / Governance
    let locks: AgoraLocksSnapshot
    
    // Optional / Legacy Support
    let phoenix: PhoenixSnapshot? 
    let standardizedOutputs: [String: StandardModuleOutput]?
    
    // Helpers
    var reasonOneLiner: String { reason }
    
    // Initializer for convenience mapping
    init(symbol: String, action: SignalAction, reason: String, evidence: [SnapshotEvidence], riskContext: SnapshotRiskContext?, locks: AgoraLocksSnapshot, phoenix: PhoenixSnapshot?, standardizedOutputs: [String: StandardModuleOutput]?, dominantSignals: [String], conflicts: [DecisionConflict]) {
        self.id = UUID()
        self.timestamp = Date()
        self.symbol = symbol
        self.action = action
        self.reason = reason
        self.overallScore = 0.0
        self.confidence = 1.0
        self.evidence = evidence
        self.riskContext = riskContext
        self.locks = locks
        self.phoenix = phoenix
        self.standardizedOutputs = standardizedOutputs
        self.dominantSignals = dominantSignals
        self.conflicts = conflicts
    }
}

struct AgoraLocksSnapshot: Codable {
    let isLocked: Bool // If true, trade is blocked
    let reasons: [String] // Why blocked? (Cooldown, Risk, Veto)
    
    // Specific Lock Details
    let cooldownUntil: Date?
    let minHoldUntil: Date?
}

struct TradingGuardsConfig: Codable {
    static let defaults = TradingGuardsConfig()
    static let shared = TradingGuardsConfig() // Fix for 'shared' access
    
    var maxDailyTrades: Int = 25
    var maxRiskScoreForBuy: Double = 20.0 // Minimum Safety Score (0-100)
    var portfolioConcentrationLimit: Double = 0.25 // Max 25% in one sector
    
    // Churn Configs
    var minTimeBetweenTradesSameSymbol: TimeInterval = 300 // 5 min
    var manualOverrideDuration: TimeInterval = 86400 // 24h
    var cooldownPulse: TimeInterval = 300 // 5m
    var cooldownCorse: TimeInterval = 2700 // 45m
    var minHoldCorse: TimeInterval = 3600 // 1h
    var minHoldTime: TimeInterval = 3600 // 1h (Generic)
    var decisionV2Enabled: Bool = true
    var cooldownAfterSell: TimeInterval = 1800 // 30m
    var reEntryWindow: TimeInterval = 3600
    var reEntryThreshold: Double = 75
}
