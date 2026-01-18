import SwiftUI

// MARK: - Alkindus Dashboard View
/// Displays calibration statistics and module performance insights.
/// Phase 1: Shadow Mode - Read-only observation statistics.

struct AlkindusDashboardView: View {
    @State private var stats: AlkindusStats?
    @State private var isLoading = true
    
    // Theme
    private let bgColor = Color(red: 0.02, green: 0.02, blue: 0.04)
    private let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let green = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(cyan)
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header Card
                            headerCard(stats: stats)
                            
                            // Module Calibration Table
                            moduleCalibrationSection(stats: stats)
                            
                            // Regime Insights
                            regimeInsightsSection(stats: stats)
                            
                            // Pending Observations
                            pendingSection(stats: stats)
                            
                            Spacer(minLength: 50)
                        }
                        .padding()
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Alkindus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(cyan)
                    }
                }
            }
        }
        .task {
            await loadStats()
        }
    }
    
    // MARK: - Header Card
    private func headerCard(stats: AlkindusStats) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(gold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALKINDUS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)
                    Text("Meta-Zeka Kalibrasyon")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Shadow Mode")
                        .font(.caption)
                        .foregroundColor(cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(cyan.opacity(0.2))
                        .cornerRadius(6)
                    
                    Text("\(stats.pendingCount) bekleyen")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Top/Weak Module
            HStack(spacing: 20) {
                if let top = stats.topModule {
                    miniStat(title: "En İyi Modül", value: top.name.capitalized, rate: top.hitRate, color: green)
                }
                
                if let weak = stats.weakestModule {
                    miniStat(title: "En Zayıf", value: weak.name.capitalized, rate: weak.hitRate, color: red)
                }
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(16)
    }
    
    private func miniStat(title: String, value: String, rate: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            HStack {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(String(format: "%.0f%%", rate * 100))
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Module Calibration Section
    private func moduleCalibrationSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODÜL KALİBRASYONU")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            ForEach(stats.calibration.modules.sorted(by: { $0.key < $1.key }), id: \.key) { module, cal in
                moduleCard(name: module, calibration: cal)
            }
            
            if stats.calibration.modules.isEmpty {
                Text("Henüz veri yok. Kararlar verildikçe burası dolacak.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
    
    private func moduleCard(name: String, calibration: ModuleCalibration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            ForEach(calibration.brackets.sorted(by: { $0.key > $1.key }), id: \.key) { bracket, bstats in
                HStack {
                    Text(bracket)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 60, alignment: .leading)
                    
                    ProgressView(value: bstats.hitRate)
                        .tint(colorForHitRate(bstats.hitRate))
                    
                    Text(String(format: "%.0f%%", bstats.hitRate * 100))
                        .font(.caption)
                        .foregroundColor(colorForHitRate(bstats.hitRate))
                        .frame(width: 40)
                    
                    Text("(\(bstats.attempts))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
    }
    
    private func colorForHitRate(_ rate: Double) -> Color {
        if rate >= 0.6 { return green }
        if rate >= 0.45 { return .orange }
        return red
    }
    
    // MARK: - Regime Insights Section
    private func regimeInsightsSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REJİM BAZLI PERFORMANS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            ForEach(stats.calibration.regimes.sorted(by: { $0.key < $1.key }), id: \.key) { regime, insight in
                VStack(alignment: .leading, spacing: 8) {
                    Text(regime.capitalized)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(insight.moduleAttempts.sorted(by: { $0.key < $1.key }), id: \.key) { module, attempts in
                        let rate = insight.hitRate(for: module)
                        HStack {
                            Text(module.capitalized)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.0f%%", rate * 100))
                                .font(.caption)
                                .foregroundColor(colorForHitRate(rate))
                        }
                    }
                }
                .padding()
                .background(cardBg)
                .cornerRadius(12)
            }
            
            if stats.calibration.regimes.isEmpty {
                Text("Rejim verisi henüz yok.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
    }
    
    // MARK: - Pending Section
    private func pendingSection(stats: AlkindusStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BEKLEYEN GÖZLEMLER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            HStack {
                Image(systemName: "hourglass")
                    .foregroundColor(cyan)
                Text("\(stats.pendingCount) karar olgunlaşma bekliyor")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Alkindus henüz veri toplamadı")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Kararlar verildikçe burada istatistikler görünecek.")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Actions
    private func loadStats() async {
        isLoading = true
        stats = await AlkindusCalibrationEngine.shared.getCurrentStats()
        isLoading = false
    }
    
    private func refresh() {
        Task {
            await loadStats()
        }
    }
}

#Preview {
    AlkindusDashboardView()
}
