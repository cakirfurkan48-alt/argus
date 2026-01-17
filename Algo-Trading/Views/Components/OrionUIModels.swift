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
}
