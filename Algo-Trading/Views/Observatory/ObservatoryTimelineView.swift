import SwiftUI

// MARK: - Observatory Timeline View
/// Displays a list of Argus decisions as "story cards"
struct ObservatoryTimelineView: View {
    @State private var decisions: [DecisionCard] = []
    @State private var isLoading = true
    @State private var selectedFilter: TimelineFilter = .all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filtre", selection: $selectedFilter) {
                    ForEach(TimelineFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Timeline List
                if isLoading {
                    Spacer()
                    ProgressView("Zaman çizelgesi yükleniyor...")
                    Spacer()
                } else if decisions.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Henüz karar kaydı yok")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Argus kararlar aldıkça burada görünecekler.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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
            .navigationTitle("🔭 Observatory")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadDecisions) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadDecisions()
            }
        }
    }
    
    private var filteredDecisions: [DecisionCard] {
        switch selectedFilter {
        case .all:
            return decisions
        case .pending:
            return decisions.filter { $0.outcome == .pending }
        case .matured:
            return decisions.filter { $0.outcome == .matured }
        case .bist:
            return decisions.filter { $0.market == "BIST" }
        case .global:
            return decisions.filter { $0.market == "US" }
        }
    }
    
    private func loadDecisions() {
        isLoading = true
        Task {
            // Load from ArgusLedger
            let events = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            await MainActor.run {
                self.decisions = events
                self.isLoading = false
            }
        }
    }
}

// MARK: - Decision Card View
struct DecisionCardView: View {
    let decision: DecisionCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Symbol Badge
                Text(decision.symbol)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                // Market Badge
                Text(decision.market)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(decision.market == "BIST" ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Timestamp
                Text(decision.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Action & Confidence
            HStack {
                // Action Badge
                HStack(spacing: 4) {
                    Image(systemName: decision.actionIcon)
                    Text(decision.action)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(decision.actionColor)
                
                Text("(\(Int(decision.confidence * 100))%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // Top Factors
            HStack(spacing: 8) {
                ForEach(decision.topFactors.prefix(3), id: \.name) { factor in
                    HStack(spacing: 2) {
                        Text(factor.emoji)
                            .font(.caption)
                        Text("\(factor.name)")
                            .font(.caption2)
                        Text(factor.value >= 0 ? "+\(Int(factor.value))" : "\(Int(factor.value))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(factor.value >= 50 ? .green : (factor.value >= 30 ? .secondary : .red))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            Divider()
            
            // Horizon & Outcome
            HStack {
                // Horizon
                Label(decision.horizon.rawValue, systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Outcome
                HStack(spacing: 4) {
                    Circle()
                        .fill(decision.outcomeColor)
                        .frame(width: 8, height: 8)
                    Text(decision.outcome.displayName)
                        .font(.caption)
                }
                
                // PnL (if matured)
                if decision.outcome == .matured, let pnl = decision.actualPnl {
                    Text(String(format: "%+.2f%%", pnl))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Supporting Models

struct DecisionCard: Identifiable {
    let id: UUID
    let symbol: String
    let market: String           // "US" or "BIST"
    let timestamp: Date
    let action: String           // "BUY", "SELL", "HOLD"
    let confidence: Double       // 0.0 - 1.0
    let topFactors: [Factor]
    let horizon: DecisionHorizon
    let outcome: DecisionOutcome
    let actualPnl: Double?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: timestamp)
    }
    
    var actionIcon: String {
        switch action {
        case "HÜCUM", "BİRİKTİR": return "arrow.up.circle.fill"
        case "AZALT", "ÇIK": return "arrow.down.circle.fill"
        default: return "minus.circle.fill"
        }
    }
    
    var actionColor: Color {
        switch action {
        case "HÜCUM": return .green
        case "BİRİKTİR": return .blue
        case "AZALT": return .orange
        case "ÇIK": return .red
        default: return .gray
        }
    }
    
    var outcomeColor: Color {
        switch outcome {
        case .pending: return .yellow
        case .matured: return .green
        case .stale: return .gray
        }
    }
    
    struct Factor {
        let name: String
        let emoji: String
        let value: Double
    }
}

enum TimelineFilter: String, CaseIterable {
    case all = "all"
    case pending = "pending"
    case matured = "matured"
    case bist = "bist"
    case global = "global"
    
    var displayName: String {
        switch self {
        case .all: return "Tümü"
        case .pending: return "Bekleyen"
        case .matured: return "Tamamlanan"
        case .bist: return "BIST"
        case .global: return "Global"
        }
    }
}

// MARK: - Preview
#Preview {
    ObservatoryTimelineView()
}
