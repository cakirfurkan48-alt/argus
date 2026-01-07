import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TradingViewModel // Singleton
    // @StateObject private var viewModel = TradingViewModel() // Removed local creation
    @State private var isAppReady = false
    @State private var selectedTab = 0
    @State private var showVoiceSheet = false
    
    var body: some View {
        ZStack {
            // Global Living Background
            ArgusGlobalBackground()
                .zIndex(0)
            
            if !isAppReady {
                ArgusCinematicIntro(onFinished: {
                    withAnimation {
                        isAppReady = true
                    }
                })
                .zIndex(2)
                .transition(.opacity)
            } else {
                ZStack(alignment: .bottom) {
                    // Main Content
                    Group {
                        switch selectedTab {
                        case 0:
                            MarketView()
                                .environmentObject(viewModel)
                        case 1:
                            ArgusCockpitView()
                                .environmentObject(viewModel)
                        case 2:
                            ArgusSimulatorView()
                        case 3:
                            PortfolioView(viewModel: viewModel)
                        case 4:
                            SettingsView(tradingViewModel: viewModel)
                        default:
                            MarketView()
                                .environmentObject(viewModel)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Custom Tab Bar (ADS Floating)
                    ArgusFloatingTabBar(selectedTab: $selectedTab, showVoiceSheet: $showVoiceSheet)
                        // Gradient Mask to hide content behind tab bar
                        .background(
                            Theme.background.opacity(0.8)
                                .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                                .frame(height: 100)
                                .offset(y: 40)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showVoiceSheet) {
            ArgusVoiceView()
                .environmentObject(viewModel)
        }
    }
}

#Preview {
    ContentView()
}
