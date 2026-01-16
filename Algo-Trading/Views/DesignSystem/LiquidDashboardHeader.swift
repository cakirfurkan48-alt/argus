import SwiftUI

// MARK: - Liquid Dashboard Header
/// Portföy görünümü için birleşik başlık.
/// Liquid Effect, bakiye bilgileri ve kontrol butonlarını (Brain, Geçmiş, Pazar Seçimi) içerir.
struct LiquidDashboardHeader: View {
    @ObservedObject var viewModel: TradingViewModel
    @Binding var selectedMarket: PortfolioView.MarketMode
    
    // Actions
    var onBrainTap: () -> Void
    var onHistoryTap: () -> Void
    
    private var isBist: Bool { selectedMarket == .bist }
    
    // Dynamic Colors
    private var themeColor: Color { isBist ? .red : Theme.accent }
    private var themeSecondary: Color { isBist ? .orange : Theme.primary }
    private var currencySymbol: String { isBist ? "₺" : "$" }
    
    // Data Calculation
    // Unified Calculation (Global + BIST)
    private var totalEquityTRY: Double {
        let globalEquityTRY = viewModel.getEquity() * viewModel.usdTryRate
        let bistEquityTRY = viewModel.getBistEquity()
        return globalEquityTRY + bistEquityTRY
    }
    
    private var totalEquityUSD: Double {
        let globalEquityUSD = viewModel.getEquity()
        let bistEquityUSD = viewModel.getBistEquity() / (viewModel.usdTryRate > 0 ? viewModel.usdTryRate : 35.0)
        return globalEquityUSD + bistEquityUSD
    }
    
    private var displayEquity: Double {
        isBist ? totalEquityTRY : totalEquityUSD
    }
    
    // Unified Cash
    private var totalCashTRY: Double {
        (viewModel.balance * viewModel.usdTryRate) + viewModel.bistBalance
    }
    
    private var totalCashUSD: Double {
        viewModel.balance + (viewModel.bistBalance / (viewModel.usdTryRate > 0 ? viewModel.usdTryRate : 35.0))
    }
    
    private var displayCash: Double {
        isBist ? totalCashTRY : totalCashUSD
    }
    
    private var realized: Double {
        // Global realized (USD) convert to TRY if needed
        let globalUSD = viewModel.getRealizedPnL()
        let rate = viewModel.usdTryRate > 0 ? viewModel.usdTryRate : 35.0
        
        if isBist {
            return globalUSD * rate // Show Global PnL in TRY (Unified) + BIST Realized (0 for now)
        } else {
            return globalUSD
        }
    }
    
    private var unrealized: Double {
        isBist ? viewModel.getBistUnrealizedPnL() : viewModel.getUnrealizedPnL()
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // A. BACKGROUND (Liquid Effect)
            LiquidEffectView(
                color: themeColor,
                intensity: isBist ? 0.8 : 0.6 // BIST biraz daha yoğun
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: themeColor.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // B. CONTENT LAYER
            VStack(spacing: 20) {
                // 1. Top Control Bar (Market Switcher & Buttons)
                HStack {
                    // Custom Glass Segmented Control
                    HStack(spacing: 0) {
                        marketToggle(title: "Global 🌎", mode: .global)
                        marketToggle(title: "BIST 🇹🇷", mode: .bist)
                    }
                    .padding(4)
                    .background(Material.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 8) {
                        glassIconButton(icon: "brain.head.profile", action: onBrainTap)
                        glassIconButton(icon: "clock.arrow.circlepath", action: onHistoryTap)
                    }
                }
                
                Spacer().frame(height: 10)
                
                // 2. Main Balance (Center)
                VStack(spacing: 6) {
                    Text("TOPLAM VARLIK (NET WORTH)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.6))
                    
                    Text("\(currencySymbol)\(String(format: "%.0f", displayEquity))")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: themeColor.opacity(0.5), radius: 15)
                }
                
                // 3. Stats Grid
                HStack(spacing: 20) {
                    statPill(title: "TOPLAM NAKİT", value: displayCash, color: .white.opacity(0.9))
                    statPill(title: "NET K/Z (Bu Pazar)", value: realized + unrealized, color: (realized + unrealized) >= 0 ? Theme.positive : Theme.negative)
                }
                .padding(.bottom, 10)
            }
            .padding(24)
        }
        .frame(height: 280) // Biraz daha uzun, çünkü kontroller içinde
    }
    
    // MARK: - Subviews
    
    private func marketToggle(title: String, mode: PortfolioView.MarketMode) -> some View {
        Button(action: {
            withAnimation(.spring()) { selectedMarket = mode }
        }) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selectedMarket == mode ? themeColor : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    selectedMarket == mode ? Color.white.opacity(1.0) : Color.clear
                )
                .clipShape(Capsule())
                // Invert text color if selected (White bg -> Theme color text)
                .foregroundColor(selectedMarket == mode ? themeColor : .white)
        }
    }
    
    private func glassIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Material.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private func statPill(title: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("\(currencySymbol)\(String(format: "%.0f", value))")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Material.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
