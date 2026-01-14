import SwiftUI
import Combine

@MainActor
class ArgusLabViewModel: ObservableObject {
    @Published var selectedAlgo: String = ArgusAlgoId.argusCoreV1
    @Published var stats: [String: UnifiedAlgoStats] = [:]
    @Published var isLoading = false
    
    // Algos to track
    let algos = [
        ArgusAlgoId.argusCoreV1,
        ArgusAlgoId.orionV1,
        ArgusAlgoId.atlasV1,
        ArgusAlgoId.aetherV1,
        ArgusAlgoId.autoPilot
    ]
    
    func loadStats() {
        self.isLoading = true
        Task {
            // Trigger Resolution first
            await ArgusLabEngine.shared.resolveUnifiedEvents(using: MarketDataProvider.shared)
            
            // Then Fetch Stats for all Algos
            var newStats: [String: UnifiedAlgoStats] = [:]
            for algo in algos {
                newStats[algo] = ArgusLabEngine.shared.getStats(for: algo)
            }
            
            // Task runs on MainActor, so we can set directly
            self.stats = newStats
            self.isLoading = false
        }
    }
}

struct ArgusLabView: View {
    @ObservedObject var tradingViewModel: TradingViewModel // Keep for dependency injection if needed
    @StateObject private var labViewModel = ArgusLabViewModel()
    @State private var showVoiceChat = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.tint)
                        .padding(.bottom, 8)
                    
                    Text("Argus Laboratuvarı")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Algoritma Performans Merkezi")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Settings Toggle
                Toggle("Argus Auto-Pilot (Sanal)", isOn: $tradingViewModel.isAutoPilotEnabled)
                    .padding()
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // Unlimited Mode Toggle (User Request)
                Toggle("⚠️ Sınırsız Pozisyon Modu (Limit Yok)", isOn: $tradingViewModel.isUnlimitedPositions)
                    .padding()
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)

                // Voice & Flight Recorder Links
                VStack(spacing: 12) {
                    // Argus Voice (New)
                    Button(action: { showVoiceChat = true }) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.purple)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text("Argus Voice")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("İnteraktif Strateji Konseyi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "mic.fill")
                                .foregroundColor(.purple)
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                    }
                    
                    // Flight Recorder
                    NavigationLink(destination: ArgusFlightRecorderView()) {
                        HStack {
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.orange)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text("Uçuş Kayıtçısı")
                                    .font(.headline)
                                    .foregroundStyle(Color.primary)
                                Text("Otopilot Karar Günlüğü")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            AlgoTabButton(title: "Argus Core", id: ArgusAlgoId.argusCoreV1, selected: $labViewModel.selectedAlgo)
                            AlgoTabButton(title: "Orion", id: ArgusAlgoId.orionV1, selected: $labViewModel.selectedAlgo)
                            AlgoTabButton(title: "Atlas", id: ArgusAlgoId.atlasV1, selected: $labViewModel.selectedAlgo)
                            AlgoTabButton(title: "Test BIST 🇹🇷", id: "BIST_TEST", selected: $labViewModel.selectedAlgo)
                        }
                        .padding(.horizontal)
                    }
                    
                    if labViewModel.selectedAlgo == "BIST_TEST" {
                         VStack {
                             Button("THYAO Verisi Çek") {
                                 Task { await BistDataService.shared.testConnection() }
                             }
                             .padding()
                             .background(Color.red)
                             .foregroundColor(.white)
                             .cornerRadius(8)
                             
                             Text("Sonuçlar Xcode konsolunda görünecek.")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                         }
                         .padding()
                    } else if labViewModel.isLoading {
                    ProgressView("Veriler İşleniyor...")
                        .padding()
                } else if let stat = labViewModel.stats[labViewModel.selectedAlgo] {
                    // KPI Grid
                    StatsContent(stat: stat)
                } else {
                    Text("Veri Bulunamadı")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.bottom)
        }
        .background(Theme.background.edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            labViewModel.loadStats()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { labViewModel.loadStats() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showVoiceChat) {
            ArgusVoiceView()
                .environmentObject(tradingViewModel)
        }
    }
}

// MARK: - Subviews

struct AlgoTabButton: View {
    let title: String
    let id: String
    @Binding var selected: String
    
    var body: some View {
        Button(action: {
            withAnimation { selected = id }
        }) {
            Text(title)
                .font(.subheadline)
                .bold()
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(selected == id ? Theme.tint : Theme.secondaryBackground)
                .foregroundColor(selected == id ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct StatsContent: View {
    let stat: UnifiedAlgoStats
    
    var body: some View {
        VStack(spacing: 24) {
            // Metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "Toplam Sinyal", value: "\(stat.totalSignals)", icon: "antenna.radiowaves.left.and.right")
                StatCard(title: "Hit Rate", value: String(format: "%.1f%%", stat.hitRate), icon: "target", color: hitRateColor(stat.hitRate))
                StatCard(title: "Ort. Getiri", value: String(format: "%.2f%%", stat.avgReturn), icon: "chart.pie.fill", color: returnColor(stat.avgReturn))
                StatCard(title: "Win / Loss", value: "\(stat.winCount) / \(stat.lossCount)", icon: "arrow.left.and.right.circle.fill")
            }
            .padding(.horizontal)
            
            // Recent Events
            VStack(alignment: .leading, spacing: 12) {
                Text("Son İşlemler")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(stat.recentEvents) { event in
                    EventRow(event: event)
                }
            }
        }
    }
    
    func hitRateColor(_ rate: Double) -> Color {
        if rate >= 60 { return .green }
        if rate >= 50 { return .yellow }
        return .red
    }
    
    func returnColor(_ ret: Double) -> Color {
        if ret > 0 { return .green }
        if ret < 0 { return .red }
        return .gray
    }
}

struct EventRow: View {
    let event: ArgusLabEvent
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(event.symbol)
                        .bold()
                    Text(event.action.rawValue)
                        .font(.caption)
                        .bold()
                        .padding(4)
                        .background(Theme.colorForAction(event.action).opacity(0.2))
                        .cornerRadius(4)
                }
                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let ret = event.returnPercent {
                Text(String(format: "%+.2f%%", ret))
                    .bold()
                    .foregroundColor(ret >= 0 ? .green : .red)
            } else {
                Text("Bekliyor")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic()
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Reusing StatCard from previous but ensuring availability
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = Theme.tint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
}
