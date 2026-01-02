import SwiftUI

struct BistPortfolioView: View {
    @StateObject private var viewModel = BistTradingViewModel()
    @State private var showSearch = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Balance Card (TL)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Toplam Varlık (TL)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(alignment: .lastTextBaseline) {
                                Text("₺")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(String(format: "%.2f", viewModel.balanceTRY + portfolioValue))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                        Image(systemName: "turkishlirasign.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Nakit")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("₺\(String(format: "%.2f", viewModel.balanceTRY))")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Hisse Değeri")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("₺\(String(format: "%.2f", portfolioValue))")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Argus Auto-Pilot
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Argus BIST Yöneticisi")
                                .font(.caption).bold()
                                .foregroundColor(.white)
                            Text(viewModel.isAutoPilotEnabled ? "Aktif: Piyasa taranıyor..." : "Pasif: Manuel Mod")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.isAutoPilotEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                }
                .padding()
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.red.opacity(0.9), Color.red.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(20)
                .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // MARK: - Portfolio List
                if viewModel.portfolio.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "case.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Portföyün Boş")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("BIST hisseleri ekleyerek başla.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: { showSearch = true }) {
                            Text("Hisse Ekle")
                                .bold()
                                .padding()
                                .background(Theme.tint)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.portfolio) { trade in
                            BistPositionRow(trade: trade, quote: viewModel.quotes[trade.symbol])
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            viewModel.loadData()
        }
        .sheet(isPresented: $showSearch) {
            BistMarketView(viewModel: viewModel)
        }
    }
    
    // Computed
    var portfolioValue: Double {
        viewModel.portfolio.reduce(0) { total, trade in
            let price = viewModel.quotes[trade.symbol]?.price ?? trade.entryPrice
            return total + (trade.quantity * price)
        }
    }
}

// MARK: - Subviews
struct BistPositionRow: View {
    let trade: BistTrade
    let quote: BistTicker?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(trade.symbol)
                    .font(.headline)
                    .bold()
                Text("\(Int(trade.quantity)) Adet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Grafik (Mini Sparkline - Placeholder)
            // İleride buraya mini BIST grafiği gelecek
            
            VStack(alignment: .trailing) {
                if let price = quote?.price {
                    Text("₺\(String(format: "%.2f", price))")
                        .bold()
                    
                    let pnl = (price - trade.entryPrice) * trade.quantity
                    let pnlPercent = ((price - trade.entryPrice) / trade.entryPrice) * 100
                    
                    HStack(spacing: 4) {
                        Image(systemName: pnl >= 0 ? "arrow.up" : "arrow.down")
                        Text("\(String(format: "%.1f", pnlPercent))%")
                        Text("(₺\(Int(pnl)))")
                    }
                    .font(.caption)
                    .foregroundColor(pnl >= 0 ? .green : .red)
                    
                } else {
                    ProgressView()
                }
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
}

