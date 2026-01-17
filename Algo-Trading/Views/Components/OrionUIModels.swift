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
    case trend, momentum, volume, cpu, output
    
    var title: String {
        switch self {
        case .trend: return "TREND ANALYSIS"
        case .momentum: return "MOMENTUM INDICATOR"
        case .volume: return "VOLUME & STRUCTURE"
        case .cpu: return "CONSENSUS ENGINE"
        case .output: return "FINAL VERDICT"
        }
    }
    
    func educationalContent(for orion: OrionScoreResult) -> String {
        switch self {
        case .trend:
            return "Trend analizi, fiyatın genel yonunu belirler. SMA 50 ve SMA 200 hareketli ortalamalari kullanilarak hesaplanir. Fiyat her iki ortalamanin uzerindeyse guclu yukselis trendi, altindaysa dusus trendi vardir."
        case .momentum:
            return "Momentum, fiyat hareketinin hizini ve gucunu olcer. RSI (Relative Strength Index) ve TSI kullanilir. RSI 70 uzerinde asiri alim, 30 altinda asiri satim sinyali verir."
        case .volume:
            return "Hacim ve yapi analizi, fiyat hareketlerinin arkasindaki gucun kalicilgini degerlendirir. Yuksek hacimli hareketler daha guvenilirdir. ADX gostergesi trend gucunu olcer."
        case .cpu:
            return "Konsensus motoru, tum gostergelerden gelen sinyalleri birlestirerek tek bir skor uretir. Her gosterge oylanir ve agirlikli ortalama alinir. Bu skor, genel piyasa durumunu yansitir."
        case .output:
            return "Nihai karar, konsensus skoruna gore belirlenir. 70 ustu guclu alim, 55-70 alim, 45-55 tut, 30-45 sat, 30 alti guclu sat olarak yorumlanir."
        }
    }
}
