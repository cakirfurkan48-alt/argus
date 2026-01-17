import Foundation
import Combine
import SwiftUI

// MARK: - MODELS

/// Holds analysis results for multiple timeframes to enable strategic decision making.
struct MultiTimeframeAnalysis {
    let daily: OrionScoreResult
    let intraday: OrionScoreResult // 4 Hour or 1 Hour
    let generatedAt: Date
    
    // Strategic Synthesis (The "Brain" Advice)
    var strategicAdvice: String {
        if daily.score > 60 && intraday.score > 60 {
            return "Tam Gaz İleri: Hem ana trend hem kısa vade momentumu seni destekliyor."
        } else if daily.score > 60 && intraday.score < 40 {
            return "Fırsat Kollama: Ana trend yukarı ama kısa vade düzeltmede. Dönüş bekle ve AL."
        } else if daily.score < 40 && intraday.score > 60 {
            return "Tuzak Uyarısı: Ölü kedi sıçraması olabilir. Ana trend hala düşüşte."
        } else {
            return "Uzak Dur: Piyasa her vadede negatif."
        }
    }
}

// MARK: - STORE

/// Orion Store (State Layer) 🏛️
/// Manages Multi-Timeframe Technical Analysis.
@MainActor
final class OrionStore: ObservableObject {
    static let shared = OrionStore()
    
    // MARK: - State
    @Published var analysis: [String: MultiTimeframeAnalysis] = [:]
    @Published var isLoading: Bool = false
    
    private init() {}
    
    // MARK: - Actions
    
    /// Triggers a robust multi-timeframe analysis.
    func ensureAnalysis(for symbol: String) async {
        // 1. Freshness Check (5 mins)
        if let existing = analysis[symbol], Date().timeIntervalSince(existing.generatedAt) < 300 {
            return 
        }
        
        self.isLoading = true
        defer { self.isLoading = false }
        
        // 2. Parallel Data Fetching & Analysis
        // We use a TaskGroup to fetch and analyze Daily and Intraday (4h/1h) concurrently.
        print("🧠 OrionStore: Starting MTF Analysis for \(symbol)...")
        
        let result = await withTaskGroup(of: (String, OrionScoreResult?).self) { group -> MultiTimeframeAnalysis? in
            
            // Task A: Daily Analysis
            group.addTask {
                let candles = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day").value
                if let data = candles, !data.isEmpty {
                    // SPY Benchmark for Relative Strength
                    let spy = await MarketDataStore.shared.ensureCandles(symbol: "SPY", timeframe: "1day").value
                    let score = await OrionAnalysisService.shared.calculateOrionScoreAsync(symbol: symbol, candles: data, spyCandles: spy)
                    return ("daily", score)
                }
                return ("daily", nil)
            }
            
            // Task B: Intraday Analysis (4 Hour)
            // Note: If 4h is not available in free tier, we fallback to 1h
            group.addTask {
                let candles = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "4h").value
                if let data = candles, !data.isEmpty {
                    // No need for SPY benchmark on intraday usually, or allow nil
                    let score = await OrionAnalysisService.shared.calculateOrionScoreAsync(symbol: symbol, candles: data)
                    return ("intraday", score)
                }
                return ("intraday", nil)
            }
            
            // Collect Results
            var dailyRes: OrionScoreResult?
            var intraRes: OrionScoreResult?
            
            for await (type, res) in group {
                if type == "daily" { dailyRes = res }
                else if type == "intraday" { intraRes = res }
            }
            
            // 3. Synthesis
            if let d = dailyRes, let i = intraRes {
                return MultiTimeframeAnalysis(daily: d, intraday: i, generatedAt: Date())
            }
            
            // Fallback: If Intraday fails (e.g. data error), duplicate daily to prevent crash, but warn.
            if let d = dailyRes {
                print("⚠️ OrionStore: Intraday data missing for \(symbol). Using Daily for both.")
                return MultiTimeframeAnalysis(daily: d, intraday: d, generatedAt: Date())
            }
            
            return nil
        }
        
        if let robustResult = result {
            self.analysis[symbol] = robustResult
            print("🧠 OrionStore: Logic Synthesis Complete. Advice: \(robustResult.strategicAdvice)")
        } else {
            print("⚠️ OrionStore: Analysis Failed for \(symbol)")
        }
    }
    
    // MARK: - Accessors
    
    func getAnalysis(for symbol: String) -> MultiTimeframeAnalysis? {
        return analysis[symbol]
    }
}
