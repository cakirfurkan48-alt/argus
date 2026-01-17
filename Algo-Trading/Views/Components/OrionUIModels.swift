import Foundation
import SwiftUI

// MARK: - Shared UI Models for Orion

enum TimeframeMode {
    case daily, intraday
}

enum SignalStatus {
    case positive, negative, neutral
}

enum CircuitNode: Equatable {
    case trend, momentum, structure, pattern, cpu, output
    
    var title: String {
        switch self {
        case .trend: return "TREND"
        case .momentum: return "MOMENTUM"
        case .structure: return "YAPI"
        case .pattern: return "FORMASYON"
        case .cpu: return "KONSENSUS"
        case .output: return "SONUÇ"
        }
    }
    
    func educationalContent(for orion: OrionScoreResult) -> String {
        switch self {
        case .trend:
            return "Trend analizi, fiyatın genel yonunu belirler. SMA 50 ve SMA 200 hareketli ortalamalari kullanilarak hesaplanir. Fiyat her iki ortalamanin uzerindeyse guclu yukselis trendi, altindaysa dusus trendi vardir."
        case .momentum:
            return "Momentum, fiyat hareketinin hızını ölçer. RSI ve MACD kullanılır."
        case .structure:
            return "Yapı analizi, destek/direnç seviyelerini ve işlem hacminin fiyata etkisini inceler."
        case .pattern:
            return "Formasyon analizi, grafikte oluşan geometrik desenleri (Çanak, Bayrak, OBO vb.) tespit eder."
        case .cpu:
            return "Konsensus motoru, tum gostergelerden gelen sinyalleri birlestirerek tek bir skor uretir. Her gosterge oylanir ve agirlikli ortalama alinir. Bu skor, genel piyasa durumunu yansitir."
        case .output:
            return "Nihai karar, konsensus skoruna gore belirlenir. 70 ustu guclu alim, 55-70 alim, 45-55 tut, 30-45 sat, 30 alti guclu sat olarak yorumlanir."
        }
    }
}
