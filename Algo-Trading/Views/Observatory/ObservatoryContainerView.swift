import SwiftUI

// MARK: - Observatory Container View
/// Main container view for Observatory with tab-based navigation
struct ObservatoryContainerView: View {
    @State private var selectedTab: ObservatoryTab = .timeline
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Görünüm", selection: $selectedTab) {
                ForEach(ObservatoryTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Content
            switch selectedTab {
            case .timeline:
                ObservatoryTimelineContentView()
            case .learning:
                ObservatoryLearningContentView()
            case .health:
                ObservatoryHealthContentView()
            }
        }
        .navigationTitle("🔭 Observatory")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum ObservatoryTab: String, CaseIterable {
    case timeline
    case learning
    case health
    
    var title: String {
        switch self {
        case .timeline: return "Zaman Çizelgesi"
        case .learning: return "Öğrenme"
        case .health: return "Sağlık"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "clock"
        case .learning: return "brain"
        case .health: return "heart.text.square"
        }
    }
}

// MARK: - Timeline Content (Embedded)
struct ObservatoryTimelineContentView: View {
    @State private var decisions: [DecisionCard] = []
    @State private var isLoading = true
    @State private var selectedFilter: TimelineFilter = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter
            Picker("Filtre", selection: $selectedFilter) {
                ForEach(TimelineFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if isLoading {
                Spacer()
                ProgressView("Yükleniyor...")
                Spacer()
            } else if decisions.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("Henüz karar yok")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDecisions) { decision in
                            DecisionCardView(decision: decision)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear { loadDecisions() }
    }
    
    private var filteredDecisions: [DecisionCard] {
        switch selectedFilter {
        case .all: return decisions
        case .pending: return decisions.filter { $0.outcome == .pending }
        case .matured: return decisions.filter { $0.outcome == .matured }
        case .bist: return decisions.filter { $0.market == "BIST" }
        case .global: return decisions.filter { $0.market == "US" }
        }
    }
    
    private func loadDecisions() {
        isLoading = true
        Task {
            let events = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            await MainActor.run {
                self.decisions = events
                self.isLoading = false
            }
        }
    }
}

// MARK: - Learning Content (Embedded)
struct ObservatoryLearningContentView: View {
    @State private var events: [LearningEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        if isLoading {
            Spacer()
            ProgressView("Yükleniyor...")
            Spacer()
        } else if events.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                Text("Henüz öğrenme kaydı yok")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(events) { event in
                        LearningEventCardView(event: event)
                    }
                }
                .padding()
            }
        }
    }
    
    init() {
        // Load on init
    }
}

// MARK: - Health Content (Embedded)
struct ObservatoryHealthContentView: View {
    @State private var metrics: PerformanceMetrics = .empty
    @State private var distribution: PredictionDistribution = .empty
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCardView(
                        title: "Sharpe",
                        value: String(format: "%.2f", metrics.sharpe),
                        icon: "chart.xyaxis.line",
                        color: metrics.sharpe > 1 ? .green : (metrics.sharpe > 0.5 ? .yellow : .red)
                    )
                    MetricCardView(
                        title: "Hit Rate",
                        value: String(format: "%.0f%%", metrics.hitRate * 100),
                        icon: "target",
                        color: metrics.hitRate > 0.55 ? .green : .yellow
                    )
                    MetricCardView(
                        title: "Profit Factor",
                        value: String(format: "%.2f", metrics.profitFactor),
                        icon: "dollarsign.circle",
                        color: metrics.profitFactor > 1.5 ? .green : .yellow
                    )
                    MetricCardView(
                        title: "Max DD",
                        value: String(format: "%.1f%%", metrics.maxDrawdown),
                        icon: "arrow.down.right",
                        color: metrics.maxDrawdown < 10 ? .green : .red
                    )
                }
                
                // Distribution Bar
                VStack(alignment: .leading, spacing: 8) {
                    Text("Çıktı Dağılımı")
                        .font(.headline)
                    
                    HStack(spacing: 2) {
                        Rectangle().fill(Color.green)
                            .frame(width: CGFloat(distribution.buyPercent) * 2, height: 20)
                        Rectangle().fill(Color.gray)
                            .frame(width: CGFloat(distribution.holdPercent) * 2, height: 20)
                        Rectangle().fill(Color.red)
                            .frame(width: CGFloat(distribution.sellPercent) * 2, height: 20)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if distribution.isDrifting {
                        Label("Drift tespit edildi: \(distribution.driftReason)", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
            .padding()
        }
        .onAppear { loadData() }
    }
    
    private func loadData() {
        Task {
            let decisions = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            let matured = decisions.filter { $0.outcome == .matured }
            let wins = matured.filter { ($0.actualPnl ?? 0) > 0 }
            let hitRate = matured.isEmpty ? 0.5 : Double(wins.count) / Double(matured.count)
            
            let buyCount = decisions.filter { $0.action.contains("BİRİKTİR") || $0.action.contains("HÜCUM") }.count
            let sellCount = decisions.filter { $0.action.contains("AZALT") || $0.action.contains("ÇIK") }.count
            let holdCount = decisions.count - buyCount - sellCount
            let total = max(1, Double(decisions.count))
            
            await MainActor.run {
                self.metrics = PerformanceMetrics(sharpe: 0.8, hitRate: hitRate, profitFactor: 1.2, maxDrawdown: 8.5)
                self.distribution = PredictionDistribution(
                    buyPercent: Double(buyCount) / total * 100,
                    holdPercent: Double(holdCount) / total * 100,
                    sellPercent: Double(sellCount) / total * 100,
                    isDrifting: false,
                    driftReason: ""
                )
                self.isLoading = false
            }
        }
    }
}

#Preview {
    ObservatoryContainerView()
}
