import Foundation

// MARK: - Chat Models
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
}

enum ChatRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

/// Service that interprets the Argus Decision into a human-readable Turkish explanation using Groq (LLaMA 3).
final class ArgusExplanationService: Sendable {
    static let shared = ArgusExplanationService()
    
    // In-Memory Cache: Key = "SYMBOL_FINAL_SCORE_DATE_HOUR"
    private var cache: [String: ArgusExplanation] = [:]
    
    private init() {}
    
    // MARK: - Chat Functionality
    
    func chat(history: [ChatMessage], contextDecisions: [ArgusDecisionResult], portfolio: [Trade]) async throws -> String {
        var messages: [GroqClient.ChatMessage] = []
        
        // System Prompt
        let systemPrompt = """
        SEN 'ARGUS'SUN. Bu algoritmik ticaret sisteminin YÖNETİCİ ZEKASISIN.
        Kullanıcı senin "Kaptanın". Ona stratejik tavsiyeler ver. Analitik ve otoriter ol.
        
        KURALLAR:
        1. SADECE TÜRKÇE KONUŞ. Asla İngilizce, Çince veya Endonezce kelime kullanma.
        2. "ATLAS sistemim...", "ORION sistemim..." gibi cümleler kurarken terminolojiye sadık kal ama robotik olma.
        3. Kısa ve net cevaplar ver. Felsefe yapma.
        
        SİSTEMLER:
        - ATLAS: Temel Analiz
        - AETHER: Makroekonomik Analiz
        - ORION: Teknik Analiz
        - HERMES: Haber Analizi
        - CRONOS: Zamanlama
        """
        messages.append(.init(role: "system", content: systemPrompt))
        
        // Portfolio Context
        if !portfolio.isEmpty {
            let openPositions = portfolio.filter { $0.isOpen }
            var portfolioDesc = "MEVCUT PORTFÖY:\n"
            for trade in openPositions {
                portfolioDesc += "- \(trade.symbol): \(trade.quantity) Adet @ $\(trade.entryPrice).\n"
            }
            messages.append(.init(role: "system", content: portfolioDesc))
        }
        
        // Decisions Context
        let uniqueDecisions = Array(contextDecisions.suffix(5))
        if !uniqueDecisions.isEmpty {
             let encoder = JSONEncoder() 
             encoder.outputFormatting = .prettyPrinted
             for decision in uniqueDecisions {
                 if let data = try? encoder.encode(decision), let str = String(data: data, encoding: .utf8) {
                     messages.append(.init(role: "system", content: "ANALİZ VERİSİ (\(decision.symbol)): \(str)"))
                 }
             }
        }
        
        // History
        for msg in history.suffix(10) {
            messages.append(.init(role: msg.role.rawValue, content: msg.content))
        }
        
        return try await GroqClient.shared.chat(messages: messages)
    }
    
    func generateExplanation(for decision: ArgusDecisionResult) async throws -> ArgusExplanation {
        // 1. Check Cache (Throttling: 1 Hour Rule)
        // Prevent API spam by reusing valid explanations for the same symbol
        let cacheKey = "\(decision.symbol)_v2"
        if let cached = cache[cacheKey], !cached.isOffline {
             let age = Date().timeIntervalSince(cached.createdAt)
             if age < 3600 { // 1 Hour
                 print("♻️ Argus: Using Cached Explanation for \(decision.symbol) (\(Int(age))s old)")
                 return cached
             }
        }
        
        // 2. Prepare Prompt
        let promptText = try buildPrompt(for: decision)
        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: "You are a JSON-speaking financial analyst. Output valid JSON only."),
            .init(role: "user", content: promptText)
        ]
        
        // 3. Request via GroqClient
        do {
            var explanation: ArgusExplanation = try await GroqClient.shared.generateJSON(messages: messages)
            explanation.createdAt = Date()
            
            // Cache & Return
            cache[cacheKey] = explanation
            return explanation
            
        } catch {
            print("❌ Groq Explanation Failed: \(error)")
            // Fallback with Real Error Reason
            let fallback = generateOfflineExplanation(for: decision, reason: error.localizedDescription)
            cache[cacheKey] = fallback
            return fallback
        }
    }
    
    // MARK: - Offline Fallback Generator
    func generateOfflineExplanation(for decision: ArgusDecisionResult, reason: String? = nil) -> ArgusExplanation {
        var title = "Analiz Tamamlandı"
        var summary = "Yapay zeka detaylı yorumu şu an oluşturamıyor. Skorları inceleyebilirsiniz."
        var bullets: [String] = []
        
        // Add Failure Reason if exists (User Requested Softer Message)
        if reason != nil {
            title = "Açıklama Servisi Hatası"
            summary = "Argus kararı ve skorlar lokal olarak hesaplandı. Ancak detaylı metinsel açıklama şu anda üretilemedi (LLM hatası / yoğunluk)."
            // bullets.append("Hata: \(failReason)") // Optional: Show simplified error code
        }
        
        // 1. Action Consensus
        if decision.finalActionCore == decision.finalActionPulse {
           bullets.append("Core ve Pulse, '\(decision.finalActionCore.rawValue)' yönünde hemfikir.")
        } else {
           bullets.append("Uzun vadede \(decision.finalActionCore.rawValue), kısa vadede \(decision.finalActionPulse.rawValue) sinyali.")
        }
        
        // 2. Component Highlights
        if decision.atlasScore > 65 { bullets.append("Atlas (Temel): Güçlü.") }
        else if decision.atlasScore < 40 { bullets.append("Atlas (Temel): Zayıf.") }
        
        if decision.orionScore > 65 { bullets.append("Orion (Teknik): Yükseliş trendi.") }
        else if decision.orionScore < 40 { bullets.append("Orion (Teknik): Düşüş trendi.") }
        
        // 3. Success Title Logic (Only if NO error, otherwise keep 'Açıklama Servisi Hatası')
        if reason == nil {
            if decision.finalScoreCore >= 75 {
                title = "Güçlü Yükseliş Potansiyeli (\(decision.letterGradeCore))"
            } else if decision.finalScoreCore <= 40 {
                title = "Zayıf Görünüm (\(decision.letterGradeCore))"
            } else {
                title = "Dengeli / Nötr Görünüm (\(decision.letterGradeCore))"
            }
        }
        
        return ArgusExplanation(
            title: title,
            summary: summary,
            bullets: bullets,
            riskNote: decision.aetherScore < 50 ? "Makro piyasa koşulları riskli." : nil,
            toneTag: "balanced",
            createdAt: Date(),
            isOffline: true
        )
    }
    
    private func buildPrompt(for decision: ArgusDecisionResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let decisionData = try encoder.encode(decision)
        let decisionString = String(data: decisionData, encoding: .utf8) ?? "{}"
        
        return """
        Sen Argus Trading Asistanı'nın beynisin. Aşağıda bir hisse senedi için hesaplanmış detaylı KARAR OBJESİ (JSON) var.
        
        BAĞLAM: \(decision.symbol)
        
        ÖZET SKORLAR:
        - CORE: \(Int(decision.finalScoreCore))/100 -> \(decision.finalActionCore.rawValue)
        - PULSE: \(Int(decision.finalScorePulse))/100 -> \(decision.finalActionPulse.rawValue)
        
        BİLEŞENLER:
        1. ATLAS (Fundamental): \(Int(decision.atlasScore))
        2. ORION (Teknik): \(Int(decision.orionScore))
        3. AETHER (Makro): \(Int(decision.aetherScore))
        4. HERMES (Haber): \(Int(decision.hermesScore))
        
        GÖREV:
        Kullanıcıya bütüncül yorum üret.
        
        KURALLAR:
        1. YANIT SADECE TÜRKÇE OLACAK. (Asla İngilizce veya Çince karakter kullanma).
        2. Profesyonel ve net ol.
        
        ÇIKTI (JSON):
        {
          "title": "Kısa Başlık",
          "summary": "2-3 cümlelik özet.",
          "bullets": ["Madde 1", "Madde 2", "Madde 3"],
          "riskNote": "Varsa risk uyarısı yoksa null",
          "toneTag": "balanced"
        }
        
        VERİLER:
        \(decisionString)
        """
    }
}
