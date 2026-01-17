import Foundation
import SwiftUI

// MARK: - Orion Text Generator
// Generates live, dynamic text analysis based on technical indicators.

struct OrionTextGenerator {
    
    // MARK: - Trend Analysis Text
    static func generateTrendText(for analysis: OrionScoreResult) -> DynamicAnalysisText {
        let trendScore = analysis.components.trend
        let isBullish = trendScore > 15
        
        var segments: [TextSegment] = []
        
        // Segment 1: Direction
        segments.append(TextSegment(text: "Trend şu an ", color: .gray))
        segments.append(TextSegment(text: isBullish ? "yükseliş eğiliminde (Bullish)" : "düşüş eğiliminde (Bearish)", color: isBullish ? .green : .red, isBold: true))
        
        // Segment 2: Detail
        segments.append(TextSegment(text: ". Hareketli ortalamalar ", color: .gray))
        if trendScore > 20 {
             segments.append(TextSegment(text: "güçlü ivme", color: .white, isBold: true))
             segments.append(TextSegment(text: " ile yukarı yönü destekliyor.", color: .gray))
        } else if trendScore < 8 {
             segments.append(TextSegment(text: "satış baskısı", color: .white, isBold: true))
             segments.append(TextSegment(text: " altında zayıf seyrediyor.", color: .gray))
        } else {
             segments.append(TextSegment(text: "yatay", color: .white, isBold: true))
             segments.append(TextSegment(text: " ve kararsız bir görünüm sergiliyor.", color: .gray))
        }
        
        return DynamicAnalysisText(segments: segments)
    }
    
    // MARK: - Momentum Analysis Text
    static func generateMomentumText(for analysis: OrionScoreResult) -> DynamicAnalysisText {
        let momentumScore = analysis.components.momentum
        var segments: [TextSegment] = []
        
        segments.append(TextSegment(text: "Momentum göstergeleri ", color: .gray))
        
        if momentumScore > 18 {
             segments.append(TextSegment(text: "aşırı alım (Overbought)", color: .orange, isBold: true))
             segments.append(TextSegment(text: " bölgesinde. Kar satışı riski var.", color: .gray))
        } else if momentumScore < 7 {
             segments.append(TextSegment(text: "aşırı satım (Oversold)", color: .green, isBold: true))
             segments.append(TextSegment(text: " bölgesinde. Tepki alımı gelebilir.", color: .gray))
        } else {
             segments.append(TextSegment(text: "dengeli", color: .cyan, isBold: true))
             segments.append(TextSegment(text: " ve stabil ilerliyor.", color: .gray))
        }
        
        return DynamicAnalysisText(segments: segments)
    }
    
    // MARK: - Volume Analysis Text
    static func generateVolumeText(for analysis: OrionScoreResult) -> DynamicAnalysisText {
        let volScore = analysis.components.structure
        var segments: [TextSegment] = []
        
        segments.append(TextSegment(text: "İşlem hacmi ve piyasa yapısı ", color: .gray))
        
        if volScore > 25 {
             segments.append(TextSegment(text: "kurumsal giriş", color: .green, isBold: true))
             segments.append(TextSegment(text: " sinyalleri veriyor. Hacim fiyatı destekliyor.", color: .gray))
        } else if volScore < 12 {
             segments.append(TextSegment(text: "zayıf", color: .orange, isBold: true))
             segments.append(TextSegment(text: ". Yükselişler hacimsiz kalıyor.", color: .gray))
        } else {
             segments.append(TextSegment(text: "nötr", color: .white, isBold: true))
             segments.append(TextSegment(text: ". Belirgin bir para girişi veya çıkışı yok.", color: .gray))
        }
        
        return DynamicAnalysisText(segments: segments)
    }
}

// MARK: - Models
struct TextSegment: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    var isBold: Bool = false
}

struct DynamicAnalysisText {
    let segments: [TextSegment]
}
