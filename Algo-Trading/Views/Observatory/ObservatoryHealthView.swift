import SwiftUI

// MARK: - Observatory Health View
/// Displays system health metrics, drift detection, and data quality alerts
struct ObservatoryHealthView: View {
    @State private var metrics: PerformanceMetrics = .empty
    @State private var distribution: PredictionDistribution = .empty
    @State private var alerts: [DataQualityAlert] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Performance Section
                    performanceSection
                    
                    // Distribution Section
                    distributionSection
                    
                    // Alerts Section
                    alertsSection
                }
                .padding()
            }
            .navigationTitle("📊 Sistem Sağlığı")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadData) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    // MARK: - Performance Section
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Son 30 Gün Performansı", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCardView(
                    title: "Sharpe Ratio",
                    value: String(format: "%.2f", metrics.sharpe),
                    icon: "chart.xyaxis.line",
                    color: metrics.sharpe > 1.0 ? .green : (metrics.sharpe > 0.5 ? .yellow : .red)
                )
                
                MetricCardView(
                    title: "Hit Rate",
                    value: String(format: "%.0f%%", metrics.hitRate * 100),
                    icon: "target",
                    color: metrics.hitRate > 0.55 ? .green : (metrics.hitRate > 0.45 ? .yellow : .red)
                )
                
                MetricCardView(
                    title: "Profit Factor",
                    value: String(format: "%.2f", metrics.profitFactor),
                    icon: "dollarsign.circle",
                    color: metrics.profitFactor > 1.5 ? .green : (metrics.profitFactor > 1.0 ? .yellow : .red)
                )
                
                MetricCardView(
                    title: "Max Drawdown",
                    value: String(format: "%.1f%%", metrics.maxDrawdown),
                    icon: "arrow.down.right",
                    color: metrics.maxDrawdown < 10 ? .green : (metrics.maxDrawdown < 20 ? .yellow : .red)
                )
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    // MARK: - Distribution Section (Prediction Drift)
    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Çıktı Dağılımı (Prediction Drift)", systemImage: "chart.pie")
                .font(.headline)
            
            HStack(spacing: 4) {
                // BUY
                Rectangle()
                    .fill(Color.green)
                    .frame(width: CGFloat(distribution.buyPercent) * 2, height: 24)
                    .overlay(
                        Text(String(format: "%.0f%%", distribution.buyPercent))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    )
                
                // HOLD
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: CGFloat(distribution.holdPercent) * 2, height: 24)
                    .overlay(
                        Text(String(format: "%.0f%%", distribution.holdPercent))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    )
                
                // SELL
                Rectangle()
                    .fill(Color.red)
                    .frame(width: CGFloat(distribution.sellPercent) * 2, height: 24)
                    .overlay(
                        Text(String(format: "%.0f%%", distribution.sellPercent))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            HStack {
                Label("AL", systemImage: "arrow.up")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Label("BEKLE", systemImage: "minus")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
                Label("SAT", systemImage: "arrow.down")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            // Drift Warning
            if distribution.isDrifting {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Çıktı dağılımı dengesiz! (\(distribution.driftReason))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    // MARK: - Alerts Section
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Veri Kalitesi Uyarıları", systemImage: "exclamationmark.shield")
                .font(.headline)
            
            if alerts.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Tüm sistemler sağlıklı")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(alerts) { alert in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: alert.icon)
                            .foregroundStyle(alert.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.subheadline.weight(.medium))
                            Text(alert.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(alert.formattedTime)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    // MARK: - Data Loading
    private func loadData() {
        isLoading = true
        Task {
            // Load metrics from validation results
            let decisions = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            
            // Calculate metrics
            let matured = decisions.filter { $0.outcome == .matured }
            let wins = matured.filter { ($0.actualPnl ?? 0) > 0 }
            let hitRate = matured.isEmpty ? 0.5 : Double(wins.count) / Double(matured.count)
            
            let pnls = matured.compactMap { $0.actualPnl }
            let profits = pnls.filter { $0 > 0 }.reduce(0, +)
            let losses = abs(pnls.filter { $0 < 0 }.reduce(0, +))
            let profitFactor = losses > 0 ? profits / losses : 2.0
            
            // Simple Sharpe approximation
            let avgPnl = pnls.isEmpty ? 0 : pnls.reduce(0, +) / Double(pnls.count)
            let variance = pnls.isEmpty ? 1 : pnls.map { pow($0 - avgPnl, 2) }.reduce(0, +) / Double(pnls.count)
            let stdDev = sqrt(variance)
            let sharpe = stdDev > 0 ? avgPnl / stdDev : 0
            
            // Max Drawdown (simplified)
            var maxDD = 0.0
            var peak = 0.0
            var equity = 0.0
            for pnl in pnls {
                equity += pnl
                if equity > peak { peak = equity }
                let dd = peak > 0 ? (peak - equity) / peak * 100 : 0
                if dd > maxDD { maxDD = dd }
            }
            
            // Distribution
            let buyCount = decisions.filter { $0.action.contains("BİRİKTİR") || $0.action.contains("HÜCUM") }.count
            let sellCount = decisions.filter { $0.action.contains("AZALT") || $0.action.contains("ÇIK") }.count
            let holdCount = decisions.count - buyCount - sellCount
            
            let total = max(1, Double(decisions.count))
            let buyPct = Double(buyCount) / total * 100
            let sellPct = Double(sellCount) / total * 100
            let holdPct = Double(holdCount) / total * 100
            
            let isDrifting = buyPct > 70 || sellPct > 70 || holdPct > 80
            let driftReason = buyPct > 70 ? "Aşırı AL" : (sellPct > 70 ? "Aşırı SAT" : (holdPct > 80 ? "Aşırı BEKLE" : ""))
            
            await MainActor.run {
                self.metrics = PerformanceMetrics(
                    sharpe: sharpe,
                    hitRate: hitRate,
                    profitFactor: profitFactor,
                    maxDrawdown: maxDD
                )
                
                self.distribution = PredictionDistribution(
                    buyPercent: buyPct,
                    holdPercent: holdPct,
                    sellPercent: sellPct,
                    isDrifting: isDrifting,
                    driftReason: driftReason
                )
                
                // Mock alerts for now
                self.alerts = []
                self.isLoading = false
            }
        }
    }
}

// MARK: - Metric Card View
struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }
}

// MARK: - Supporting Models

struct PerformanceMetrics {
    let sharpe: Double
    let hitRate: Double
    let profitFactor: Double
    let maxDrawdown: Double
    
    static var empty: PerformanceMetrics {
        PerformanceMetrics(sharpe: 0, hitRate: 0, profitFactor: 0, maxDrawdown: 0)
    }
}

struct PredictionDistribution {
    let buyPercent: Double
    let holdPercent: Double
    let sellPercent: Double
    let isDrifting: Bool
    let driftReason: String
    
    static var empty: PredictionDistribution {
        PredictionDistribution(buyPercent: 33, holdPercent: 34, sellPercent: 33, isDrifting: false, driftReason: "")
    }
}

struct DataQualityAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    
    enum AlertSeverity {
        case warning, error, info
    }
    
    var icon: String {
        switch severity {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
    
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Preview
#Preview {
    ObservatoryHealthView()
}
