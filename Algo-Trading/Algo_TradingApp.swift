//
//  Algo_TradingApp.swift
//  Algo-Trading
//
//  Created by Argus Team on 2.12.2025.
//

import SwiftUI
import SwiftData

@main
struct Algo_TradingApp: App {
    // Create container manually to access context easily for Singleton injection
    let container: ModelContainer
    
    // Unified Singleton ViewModel (Legacy - Geçiş döneminde korunuyor)
    @StateObject private var tradingViewModel = TradingViewModel()
    
    // FAZ 2: Yeni modüler koordinatör (Paralel çalışıyor)
    @StateObject private var coordinator = AppStateCoordinator.shared

    init() {
        do {
            let modelContainer = try ModelContainer(for: ShadowTradeSession.self, MissedOpportunityLog.self)
            self.container = modelContainer
            
            // SETUP NOTIFICATION DELEGATE
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            
            // Inject into Singleton immediately
            Task { @MainActor in
                LearningPersistenceManager.shared.setContext(modelContainer.mainContext)
                
                // ONE-TIME PORTFOLIO RESET (v4 Migration - Temiz Başlangıç)
                let resetKey = "portfolio_v4_reset_done"
                if !UserDefaults.standard.bool(forKey: resetKey) {
                    print("🔄 ONE-TIME RESET: Portföy sıfırlanıyor (v4 migration)...")
                    PortfolioEngine.shared.resetPortfolio()
                    UserDefaults.standard.set(true, forKey: resetKey)
                    print("✅ ONE-TIME RESET: Tamamlandı. USD: $100K, TRY: ₺1M")
                }
            }
        } catch {
            print("🚨 CRITICAL: Failed to create ModelContainer: \(error)")
            // FALLBACK: Create in-memory container to prevent crash
            do {
                let schema = Schema([ShadowTradeSession.self, MissedOpportunityLog.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = try ModelContainer(for: schema, configurations: [config])
                print("⚠️ Using In-Memory Safe Container")
            } catch let fallbackError {
                // GRACEFUL DEGRADATION: Use absolute minimal container
                // Instead of crashing, log and use empty schema
                print("🚨 FATAL FALLBACK FAILED: \(fallbackError)")
                print("🛡️ Using minimal empty container - some features may be unavailable")
                
                // Minimal fallback - sadece app açılsın
                self.container = try! ModelContainer(for: Schema([]))
            }
        }
    }

    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasAcceptedDisclaimer {
                    ContentView()
                        .environmentObject(tradingViewModel)
                        .environmentObject(coordinator) // Yeni koordinatör
                        .environmentObject(coordinator.watchlist) // Yeni WatchlistVM
                        .environmentObject(coordinator.portfolio) // Yeni PortfolioVM
                        .task {
                            // One-time startup logic
                            tradingViewModel.bootstrap()
                            
                            // 🧠 Chiron: Start background learning analysis
                            Task.detached(priority: .background) {
                                // Delay to let app settle
                                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                                await ChironLearningJob.shared.runFullAnalysis()
                                print("🧠 Chiron: Startup learning cycle completed")
                            }
                        }
                } else {
                    DisclaimerView()
                }
            }
        }
        .modelContainer(container)
    }
}
