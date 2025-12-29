import Foundation

/// Helper structure for Advisor feedback
struct AdvisorNote: Codable, Sendable, Identifiable {
    var id: String { module }
    let module: String // "Athena", "Demeter", "Chiron"
    let advice: String
    let tone: AdvisorTone
    
    enum AdvisorTone: String, Codable, Sendable {
        case positive = "green"
        case caution = "yellow"
        case warning = "red" // Veto level
        case neutral = "gray"
    }
}

/// Generates educational and advisory sentences for the Council
struct CouncilAdvisorGenerator {
    
    // MARK: - Athena (Smart Beta / Variance)
    static func generateAthenaAdvice(result: AthenaFactorResult?) -> AdvisorNote {
        guard let res = result else {
            return AdvisorNote(module: "Athena", advice: "Veri yetersiz, faktör analizi yapılamadı.", tone: .neutral)
        }
        
        // Low Volatility Factor
        if res.riskFactorScore < 40 { // Low Vol Regime Proxy
            return AdvisorNote(
                module: "Athena",
                advice: "Volatilite düşük, istikrarlı yükseliş trendi. Akıllı beta 'Low Vol' faktörünü destekliyor.",
                tone: .positive
            )
        } else if res.riskFactorScore > 70 { // High Vol Regime Proxy
             return AdvisorNote(
                module: "Athena",
                advice: "Yüksek varyans tespit edildi. Fiyat hareketleri sert olabilir, pozisyon büyüklüğüne dikkat.",
                tone: .caution
            )
        } else {
             return AdvisorNote(
                module: "Athena",
                advice: "Faktörler nötr. Belirgin bir akıllı beta avantajı veya dezavantajı yok.",
                tone: .neutral
            )
        }
    }
    
    // MARK: - Demeter (Sector Rotation)
    static func generateDemeterAdvice(score: DemeterScore?) -> AdvisorNote {
        guard let s = score else {
             return AdvisorNote(module: "Demeter", advice: "Sektör verisi bulunamadı.", tone: .neutral)
        }
        
        if s.totalScore > 70 {
             return AdvisorNote(
                module: "Demeter",
                advice: "\(s.sector.rawValue) sektörü şu an piyasanın gözdesi. Sektörel rüzgar arkamızda.",
                tone: .positive
            )
        } else if s.totalScore < 30 {
             return AdvisorNote(
                module: "Demeter",
                advice: "\(s.sector.rawValue) sektörü zayıf performans gösteriyor. Sektör rotasyonu aleyhimize.",
                tone: .warning
            )
        } else {
             return AdvisorNote(
                module: "Demeter",
                advice: "Sektör performansı piyasa ortalamasında.",
                tone: .neutral
            )
        }
    }
    
    // MARK: - Chiron (Risk Manager)
    static func generateChironAdvice(result: ChronosResult?, action: ArgusAction) -> AdvisorNote {
        // Chiron checks Trade Duration & Risk Context
        guard let res = result else {
             return AdvisorNote(module: "Chiron", advice: "Zaman analizi eksik.", tone: .neutral)
        }
        
        // Example: If buying into an OLD trend
        /*
        if action == .buy || action == .aggressiveBuy {
            if res.trendAgeDays > 200 {
                 return AdvisorNote(
                    module: "Chiron",
                    advice: "Trend \(res.trendAgeDays) gündür devam ediyor. Olgun bir trende giriyoruz, kâr almayı yakın tut.",
                    tone: .caution
                )
            } else if res.trendAgeDays < 20 {
                 return AdvisorNote(
                    module: "Chiron",
                    advice: "Trend henüz yeni (\(res.trendAgeDays) gün). Erken giriş avantajı olabilir.",
                    tone: .positive
                )
            }
        }
        */
        
        return AdvisorNote(
            module: "Chiron",
            advice: "Risk parametreleri normal seviyede.",
            tone: .neutral
        )
    }
}
