import Foundation

// MARK: - Fed Master Engine
/// Council member responsible for Fed and interest rate analysis
struct FedMasterEngine: MacroCouncilMember, Sendable {
    let id = "fed_master"
    let name = "Fed Ustası"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // Yield curve inversion = recession signal
        if macro.yieldCurveInverted {
            confidence = 0.85
            stance = .defensive
            reasoning = "Getiri eğrisi ters - Resesyon sinyali"
        }
        // High and rising rates
        else if let fedRate = macro.fedFundsRate, fedRate > 5.0 {
            confidence = 0.75
            stance = .cautious
            reasoning = "Fed faizi yüksek (%\(String(format: "%.2f", fedRate))) - Likidite azalıyor"
        }
        // Low rates = risk on
        else if let fedRate = macro.fedFundsRate, fedRate < 2.0 {
            confidence = 0.80
            stance = .riskOn
            reasoning = "Düşük faiz ortamı (%\(String(format: "%.2f", fedRate))) - Likidite bol"
        }
        // 10Y yield analysis
        else if let tenY = macro.tenYearYield {
            if tenY > 4.5 {
                confidence = 0.70
                stance = .cautious
                reasoning = "10Y getiri yüksek (%\(String(format: "%.2f", tenY))) - Bono rekabeti"
            } else if tenY < 3.0 {
                confidence = 0.70
                stance = .riskOn
                reasoning = "Düşük 10Y getiri - Hisse cazip"
            }
        }
        else {
            return nil
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        if macro.yieldCurveInverted && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto, 
                             reasoning: "Getiri eğrisi ters - Risk alma tehlikeli", weight: 1.0)
        }
        
        if let fedRate = macro.fedFundsRate, fedRate > 5.5 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Yüksek faiz - Risk azalt", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Fed nötr", weight: 0.5)
    }
}

// MARK: - Sentiment Master Engine
/// Council member responsible for market sentiment (VIX, Fear & Greed)
struct SentimentMasterEngine: MacroCouncilMember, Sendable {
    let id = "sentiment_master"
    let name = "Duygu Ustası"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // VIX Analysis
        if let vix = macro.vix {
            if vix > 35 {
                confidence = 0.85
                stance = .riskOff
                reasoning = "Aşırı korku (VIX: \(Int(vix))) - Panik modu"
            } else if vix > 25 {
                confidence = 0.75
                stance = .defensive
                reasoning = "Korku yükseliyor (VIX: \(Int(vix)))"
            } else if vix < 12 {
                confidence = 0.70
                stance = .cautious
                reasoning = "Rehavet (VIX: \(Int(vix))) - Dikkatli ol"
            } else if vix < 18 {
                confidence = 0.75
                stance = .riskOn
                reasoning = "Sakin piyasa (VIX: \(Int(vix)))"
            }
        }
        
        // Fear & Greed
        if let fg = macro.fearGreedIndex {
            if fg < 20 {
                confidence = max(confidence, 0.85)
                stance = .riskOn  // Contrarian - extreme fear = buy
                reasoning = "Aşırı korku (F&G: \(Int(fg))) - Kontrarian AL"
            } else if fg > 80 {
                confidence = max(confidence, 0.80)
                stance = .defensive
                reasoning = "Aşırı açgözlülük (F&G: \(Int(fg))) - Düzeltme riski"
            }
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        let vix = macro.vix ?? 20
        
        if vix > 35 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "VIX çok yüksek - Panik modu", weight: 1.0)
        }
        
        if let fg = macro.fearGreedIndex, fg > 85 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Aşırı açgözlülük - Düzeltme yakın", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Duygu nötr", weight: 0.5)
    }
}

// MARK: - Sector Master Engine
/// Council member responsible for sector rotation analysis
struct SectorMasterEngine: MacroCouncilMember, Sendable {
    let id = "sector_master"
    let name = "Sektör Ustası"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        guard let phase = macro.sectorRotation else { return nil }
        
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        switch phase {
        case .earlyExpansion:
            confidence = 0.80
            stance = .riskOn
            reasoning = "Erken genişleme - Tech ve Finans liderliği"
        case .lateExpansion:
            confidence = 0.70
            stance = .cautious
            reasoning = "Geç genişleme - Enerji ve Hammadde liderliği"
        case .earlyRecession:
            confidence = 0.85
            stance = .defensive
            reasoning = "Erken resesyon - Savunmacı sektörlere geç"
        case .lateRecession:
            confidence = 0.75
            stance = .cautious
            reasoning = "Geç resesyon - Dipten dönüş aranıyor"
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        guard let phase = macro.sectorRotation else {
            return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Faz belirsiz", weight: 0.3)
        }
        
        if phase == .earlyRecession && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Resesyon başlıyor - Risk azalt", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Sektör rotasyonu nötr", weight: 0.5)
    }
}

// MARK: - Cycle Master Engine
/// Council member responsible for economic cycle analysis
struct CycleMasterEngine: MacroCouncilMember, Sendable {
    let id = "cycle_master"
    let name = "Döngü Ustası"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // GDP + Unemployment analysis
        if let gdp = macro.gdpGrowth, let unemployment = macro.unemploymentRate {
            if gdp > 3 && unemployment < 4 {
                confidence = 0.80
                stance = .riskOn
                reasoning = "Güçlü ekonomi: GDP +%\(String(format: "%.1f", gdp)), İşsizlik %\(String(format: "%.1f", unemployment))"
            } else if gdp < 0 {
                confidence = 0.85
                stance = .defensive
                reasoning = "Negatif GDP: %\(String(format: "%.1f", gdp)) - Resesyon"
            } else if unemployment > 6 {
                confidence = 0.75
                stance = .cautious
                reasoning = "Yüksek işsizlik: %\(String(format: "%.1f", unemployment))"
            }
        }
        
        // Inflation
        if let inflation = macro.inflationRate {
            if inflation > 5 {
                confidence = max(confidence, 0.75)
                stance = .cautious
                reasoning += " | Yüksek enflasyon: %\(String(format: "%.1f", inflation))"
            }
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        if let gdp = macro.gdpGrowth, gdp < -1 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Resesyon - Risk al değil", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Döngü nötr", weight: 0.5)
    }
}

// MARK: - Correlation Master Engine
/// Council member responsible for cross-asset correlation analysis
struct CorrelationMasterEngine: MacroCouncilMember, Sendable {
    let id = "correlation_master"
    let name = "Korelasyon Ustası"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // Market breadth
        if let adRatio = macro.advanceDeclineRatio {
            if adRatio > 2.0 {
                confidence = 0.75
                stance = .riskOn
                reasoning = "Güçlü piyasa genişliği (A/D: \(String(format: "%.1f", adRatio)))"
            } else if adRatio < 0.5 {
                confidence = 0.80
                stance = .defensive
                reasoning = "Zayıf piyasa genişliği (A/D: \(String(format: "%.1f", adRatio)))"
            }
        }
        
        // Percent above 200MA
        if let above200 = macro.percentAbove200MA {
            if above200 > 70 {
                confidence = max(confidence, 0.75)
                stance = .riskOn
                reasoning += " | %\(Int(above200)) hisse 200MA üstünde"
            } else if above200 < 30 {
                confidence = max(confidence, 0.80)
                stance = .defensive
                reasoning = "Sadece %\(Int(above200)) hisse 200MA üstünde - Zayıf piyasa"
            }
        }
        
        // Put/Call ratio
        if let pcr = macro.putCallRatio {
            if pcr > 1.2 {
                confidence = max(confidence, 0.70)
                stance = .riskOn  // Contrarian
                reasoning += " | Yüksek Put/Call (\(String(format: "%.2f", pcr))) - Korku yüksek"
            } else if pcr < 0.7 {
                confidence = max(confidence, 0.70)
                stance = .cautious
                reasoning += " | Düşük Put/Call (\(String(format: "%.2f", pcr))) - Rehavet"
            }
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        if let above200 = macro.percentAbove200MA, above200 < 20 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Piyasa çok zayıf - Risk almak tehlikeli", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Korelasyon nötr", weight: 0.5)
    }
}
