import Foundation

/// Sirkiye Engine (Project Turquoise)
/// Specialized Political & Macro Cortex for Turkey Markets
/// Replaces standard Aether analysis with "Street Smart" logic.
/// Tracks: FX Volatility, Political Atmosphere, Global Pressure.
actor SirkiyeEngine {
    static let shared = SirkiyeEngine()
    
    struct SirkiyeInput {
        let usdTry: Double          // Current USD/TRY rate
        let usdTryPrevious: Double  // Previous Close
        let dxy: Double?            // Global Dollar Strength
        let brentOil: Double?       // Energy Cost
        let globalVix: Double?      // Global Fear
        let newsSnapshot: HermesNewsSnapshot? // For Political Cortex
    }
    
    // MARK: - Public API
    
    func analyze(input: SirkiyeInput) -> AetherDecision {
        let timestamp = Date()
        
        // 1. Political Cortex (The "Sirkiye" Special)
        // Detects systemic risks regardless of financial data.
        let (politicalScore, politicalMode, politicalReason) = analyzePoliticalAtmosphere(news: input.newsSnapshot)
        
        // If Political Panic is triggered, it overrides everything.
        if politicalMode == .panic {
            return createPanicDecision(reason: politicalReason, timestamp: timestamp)
        }
        
        // 2. Local Stress (USD/TRY)
        let fxChange = (input.usdTry - input.usdTryPrevious) / input.usdTryPrevious * 100.0
        let localStressScore: Double
        
        if fxChange > 3.0 {
            localStressScore = 0.0 // Extreme Stress
        } else if fxChange > 1.5 {
            localStressScore = 20.0 // High Stress
        } else if fxChange < -0.5 {
            localStressScore = 80.0 // FX Relief
        } else {
            localStressScore = 60.0 // Stable
        }
        
        // 3. Global Pressure
        var globalScore = 50.0
        if let dxy = input.dxy {
            if dxy > 106 { globalScore -= 15 }
            else if dxy < 100 { globalScore += 15 }
        }
        if let oil = input.brentOil {
            if oil > 90 { globalScore -= 10 }
            else if oil < 75 { globalScore += 10 }
        }
        if let vix = input.globalVix {
            if vix > 30 { globalScore -= 20 }
            else if vix > 20 { globalScore -= 10 }
            else if vix < 15 { globalScore += 10 }
        }
        
        // 4. Synthesis
        // Weights: Political (Hidden hand) > FX (50%) > Global (20%) > News Sentiment (30%)
        
        var newsSentimentScore = 50.0
        if let snapshot = input.newsSnapshot, let sentiment = snapshot.aggregatedSentiment {
            newsSentimentScore = ((sentiment + 1.0) / 2.0) * 100.0
        }
        
        // Apply "Sirkiye" weighting
        // If Political Cortex is uneasy (but not panic), it drags score down.
        var finalScore = (localStressScore * 0.5) + (globalScore * 0.2) + (newsSentimentScore * 0.3)
        
        // Political Penalty
        if politicalMode == .fear {
            finalScore -= 20.0
            finalScore = max(0, finalScore)
        }
        
        let finalStance: MacroStance
        if finalScore < 30 { finalStance = .riskOff }
        else if finalScore < 50 { finalStance = .defensive }
        else if finalScore < 75 { finalStance = .cautious }
        else { finalStance = .riskOn }
        
        let reason = "Kur: %\(String(format: "%.2f", fxChange)) | \(politicalReason) | Global: \(Int(globalScore))"
        
        let proposal = MacroProposal(
            proposer: "Sirkiye",
            proposerName: "Sirkiye (Turquoise)",
            stance: finalStance,
            confidence: finalScore / 100.0,
            reasoning: reason
        )
        
        return AetherDecision(
            stance: finalStance,
            marketMode: politicalMode == .neutral ? .neutral : politicalMode,
            netSupport: finalScore / 100.0,
            isStrongSignal: finalScore > 75 || finalScore < 25,
            winningProposal: proposal,
            votes: [],
            warnings: politicalMode == .fear ? [politicalReason] : [],
            timestamp: timestamp
        )
    }
    
    // MARK: - Political Cortex (Standardized Historical Data)
    
    // 1. Regime & Systemic Crisis (Severity: 100 - PANIC)
    // Triggers: Regime change, legal coups, direct democracy threats.
    private let regimeKeywords = [
        "siyasi yasak", "hapis cezası", "kayyum", "darbe", "sıkıyönetim",
        "kapatma davası", "anayasa kitapçığı", "erken seçim", "dokunulmazlık"
    ]
    
    // 2. Economic Management Crisis (Severity: 80 - CRASH)
    // Triggers: Loss of central bank independence, irrational policy shifts.
    private let economicManKeywords = [
        "görevden alma", "merkez bankası başkanı", "naci ağbal", "gece yarısı kararnamesi",
        "arka kapı", "kur korumalı", "faiz inadı", "tüik başkanı", "istifa"
    ]
    
    // 3. Diplomatic & Geopolitical (Severity: 60 - HIGH STRESS)
    // Triggers: Sanctions, war risks, isolation.
    private let diplomaticKeywords = [
        "rahip brunson", "yaptırım", "halkbank davası", "s400", "f16 krizi",
        "gri liste", "büyükelçi", "istenmeyen adam", "nota verilmesi", "sınır ötesi"
    ]
    
    // 4. Social & Civil Unrest (Severity: 40 - TENSION)
    // Triggers: Protests, social instability.
    private let socialKeywords = [
        "gezi", "boğaziçi", "sokak çağrısı", "eylem", "gaz müdahalesi", "gözaltı"
    ]

    private func analyzePoliticalAtmosphere(news: HermesNewsSnapshot?) -> (Double, MarketMode, String) {
        guard let news = news, !news.insights.isEmpty else {
            return (50.0, .neutral, "Politik Veri Yok (Nötr)")
        }
        
        var totalImpact = 0.0
        var criticalTopicsFound: [String] = []
        var maxCategorySeverity = 0
        
        for insight in news.insights {
            let text = (insight.headline + " " + insight.summaryTRLong).lowercased()
            var categoryMultiplier = 0.5 // Default noise weight
            var detectedTopic: String? = nil
            var currentSeverity = 0
            
            // 1. Regime & Systemic (Multiplier: 4.0 - Critical)
            for word in regimeKeywords {
                if text.contains(word) {
                    categoryMultiplier = 4.0
                    detectedTopic = word.uppercased()
                    currentSeverity = 4
                    break
                }
            }
            
            // 2. Economic Management (Multiplier: 3.0 - High)
            if detectedTopic == nil {
                for word in economicManKeywords {
                    // Context check: Must be related to officials/institutions
                    if text.contains(word) && (text.contains("merkez") || text.contains("başkan") || text.contains("bakan") || text.contains("kurul")) {
                        categoryMultiplier = 3.0
                        detectedTopic = word.uppercased()
                        currentSeverity = 3
                        break
                    }
                }
            }
            
            // 3. Diplomatic (Multiplier: 2.0 - Moderate)
            if detectedTopic == nil {
                for word in diplomaticKeywords {
                    if text.contains(word) {
                        categoryMultiplier = 2.0
                        detectedTopic = word.uppercased()
                        currentSeverity = 2
                        break
                    }
                }
            }
            
            // 4. Social (Multiplier: 1.5)
            if detectedTopic == nil {
                for word in socialKeywords {
                    if text.contains(word) {
                        categoryMultiplier = 1.5
                        detectedTopic = word.uppercased()
                        currentSeverity = 1
                        break
                    }
                }
            }
            
            // 5. Positive Catalysts (Multiplier: 3.0 - Bullish Booster)
            // Triggers: Credit upgrades, rational policy moves, gray list exit.
            if detectedTopic == nil {
                let positiveKeywords = [
                    "not artışı", "not artırımı", "görünüm pozitif", "yatırım yapılabilir seviye",
                    "moody's", "fitch", "s&p",
                    "gri liste çıkış", "gri listeden çıktı",
                    "mehmet şimşek", "rasyonel zemin", "cds düşüş",
                    "swap hattı", "swap kanalı açıldı", "yabancı girişi"
                ]
                
                for word in positiveKeywords {
                    if text.contains(word) {
                        // Only boost if sentiment is actually positive
                        if insight.sentiment == .strongPositive || insight.sentiment == .weakPositive {
                            categoryMultiplier = 3.0 // Significant Boost
                            detectedTopic = word.uppercased()
                            // No severity for positive
                        }
                        break
                    }
                }
            }
            
            // Calculate Raw Sentiment Value (-10 to +10)
            let sentimentValue: Double
            switch insight.sentiment {
            case .strongPositive: sentimentValue = 10.0
            case .weakPositive: sentimentValue = 5.0
            case .neutral: sentimentValue = 0.0
            case .weakNegative: sentimentValue = -5.0
            case .strongNegative: sentimentValue = -10.0
            }
            
            // Apply Multiplier if a topic was found, otherwise ignore general news in this context
            if let topic = detectedTopic {
                let weightedImpact = sentimentValue * categoryMultiplier
                totalImpact += weightedImpact
                criticalTopicsFound.append("\(topic)(\(insight.sentiment.rawValue))")
                if currentSeverity > maxCategorySeverity && sentimentValue < 0 {
                    maxCategorySeverity = currentSeverity
                }
            }
        }
        
        // Final Score Calculation (Baseline 55)
        // Max theoretical negative impact: -10 * 4 * 3 items = -120 -> Score 0
        var finalScore = 55.0 + totalImpact
        finalScore = max(0.0, min(100.0, finalScore))
        
        // Determine Mode based on Final Score and Max Severity of Negative topics
        let detectedMode: MarketMode
        let description: String
        
        if finalScore < 20 {
            detectedMode = .panic // Explicit Panic
            description = "SİRKİYE ALARMI: Kritik Seviyede Risk! (\(criticalTopicsFound.prefix(2).joined(separator: ", ")))"
        } else if finalScore < 40 {
            detectedMode = .fear // General Fear
            description = "Yüksek Politik Tansiyon (%100 Koruma Önerilir). Konu: \(criticalTopicsFound.first ?? "Bilinmiyor")"
        } else if finalScore < 60 {
            detectedMode = .neutral
            description = "Politik Atmosfer Kararsız/Nötr"
        } else {
            detectedMode = .greed // Or Neutral-Positive
            description = "Politik Risk Priminde Düşüş (Olumlu)"
        }
        
        // Safety Override: If keywords found but sentiment was somehow positive, we trust the score.
        // But if score suggests Panic, we return panic.
        
        return (finalScore, detectedMode, description)
    }
    
    private func createPanicDecision(reason: String, timestamp: Date) -> AetherDecision {
        let proposal = MacroProposal(
            proposer: "Sirkiye",
            proposerName: "Sirkiye (Kırmızı Alarm)",
            stance: .riskOff,
            confidence: 1.0,
            reasoning: reason
        )
        
        return AetherDecision(
            stance: .riskOff,
            marketMode: .panic,
            netSupport: 0.0,
            isStrongSignal: true,
            winningProposal: proposal,
            votes: [],
            warnings: ["⚠️ \(reason)"],
            timestamp: timestamp
        )
    }
}
