import Foundation

/// Handles interaction with AI (Groq/LLaMA 3) for Hermes News Analysis
/// Migrated from Gemini to Groq for centralized reliability.
final class HermesLLMService: Sendable {
    static let shared = HermesLLMService()
    
    private init() {}
    
    /// Batched Analysis using Groq
    func analyzeBatch(_ articles: [NewsArticle]) async throws -> [HermesSummary] {
        if articles.isEmpty { return [] }
        
        // 1. Prepare Prompt
        // 1. Prepare Prompt
        // Limit to 3 articles to prevent context overflow and reduce cost/latency
        let topArticles = Array(articles.prefix(3))
        let promptText = buildBatchPrompt(topArticles)
        
        let messages: [GroqClient.ChatMessage] = [
            .init(role: "system", content: "You are a financial news analyst JSON generator. Always output valid JSON matching the schema."),
            .init(role: "user", content: promptText)
        ]
        
        // 2. Request via GroqClient (Handles Rate Limit & Fallback internally)
        // Use 'llama-3.1-8b-instant' for High Volume / Low Intelligence tasks (Summarization)
        // This saves the 70b TPM for Argus Voice.
        do {
            let responseDTO: HermesBatchResponse = try await GroqClient.shared.generateJSON(
                messages: messages
            )
            
            // 3. Map to Model
            return responseDTO.results.compactMap { (item: HermesBatchItem) -> HermesSummary? in
                guard let original = articles.first(where: { $0.id == item.id }) else { return nil }
                
                // v2.2: Sentiment-Score Alignment Check (The "Sallamasyon" Fix)
                var correctedScore = item.impact_score
                
                if let sentiment = item.sentiment?.uppercased() {
                    if sentiment == "POSITIVE" && correctedScore < 55 {
                        // Hallucination Fix: Text says Positive but Score is low. Boost it.
                        correctedScore = max(70.0, correctedScore + 30.0) 
                    } else if sentiment == "NEGATIVE" && correctedScore > 45 {
                        // Hallucination Fix: Text says Negative but Score is high. Crush it.
                         correctedScore = min(30.0, correctedScore - 30.0)
                    } else if sentiment == "NEUTRAL" {
                        // Pull towards 50
                        correctedScore = 50.0
                    }
                }
                
                return HermesSummary(
                    id: item.id,
                    symbol: original.symbol,
                    summaryTR: item.summary_tr,
                    impactCommentTR: item.impact_comment_tr,
                    impactScore: Int(correctedScore), // Cast to Int
                    relatedSectors: item.related_sectors,
                    rippleEffectScore: Int(item.ripple_effect_score), // Cast to Int
                    createdAt: Date(),
                    mode: .full
                )
            }
        } catch {
            print("❌ Hermes Analysis Failed: \(error)")
            // Map Groq Rate Limit to logical error
            let nsError = error as NSError
            if nsError.code == 429 {
                throw HermesError.quotaExhausted
            }
            throw error // Rethrow to let Coordinator handle Fallback
        }
    }
    
    private func buildBatchPrompt(_ articles: [NewsArticle]) -> String {
        var articlesText = ""
        for (index, article) in articles.enumerated() {
            articlesText += """
            [NEWS \(index + 1)]
            ID: \(article.id)
            Symbol: \(article.symbol)
            Headline: \(article.headline)
            Summary: \(article.summary ?? "")
            
            """
        }
        
        return """
        Sen Argus Terminal içindeki Hermes v2.1 modülüsün.
        Görevin aşağıdaki haberleri finansal ve BAĞLAMSAL açıdan analiz etmek.
        
        GİRDİ:
        \(articlesText)
        
        GÖREV:
        Her bir haber için analiz yap ve JSON üret.
        
        KURALLAR:
        Sen Argus Terminal içindeki Hermes v2.2 modülüsün.
        Görevin aşağıdaki haberleri finansal ve BAĞLAMSAL açıdan analiz etmek.
        
        GİRDİ:
        \(articlesText)
        
        GÖREV:
        Her bir haber için analiz yap ve JSON üret.
        
        PUANLAMA KURALLARI (KESİN UYULMALI):
        - POSITIVE: 65 - 100 arası. (65 = Hafif Olumlu, 100 = Game Changer)
        - NEGATIVE: 0 - 35 arası. (0 = İflas/Kriz, 35 = Hafif Olumsuz)
        - NEUTRAL: 45 - 55 arası. (Piyasayı etkilemez)
        * Asla Sentiment ile Puan çelişmemeli (Örn: Positive deyip 40 verme).
        
        KURALLAR:
        1. summary_tr: Türkçe 1 cümlelik net özet.
        2. impact_comment_tr: "Hisse için [olumlu/olumsuz/nötr] bir gelişme." şeklinde 1 cümlelik yorum.
        3. sentiment: "POSITIVE", "NEGATIVE" veya "NEUTRAL" (BÜYÜK HARF).
        4. impact_score: Yukarıdaki aralıklara göre bir tamsayı.
        5. related_sectors: İngilizce sektör etiketleri (Örn: "Energy", "Tech").
        6. ripple_effect_score: Piyasaya yayılma potansiyeli (0-100).
        
        ÇIKTI FORMATI (JSON OBJE):
        {
          "results": [
            {
              "id": "Haber ID'si aynen kopyalanmalı",
              "summary_tr": "...",
              "impact_comment_tr": "...",
              "sentiment": "POSITIVE",
              "impact_score": 75,
              "related_sectors": ["Sector1"],
              "ripple_effect_score": 60
            }
          ]
        }
        """
    }
}


