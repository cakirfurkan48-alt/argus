import SwiftUI

// MARK: - Observatory Learning View
/// Displays a list of Chiron learning events (weight updates)
struct ObservatoryLearningView: View {
    @State private var events: [LearningEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Öğrenme geçmişi yükleniyor...")
                    Spacer()
                } else if events.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Henüz öğrenme kaydı yok")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Chiron ağırlıkları güncelledikçe burada görünecekler.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
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
            .navigationTitle("🧠 Öğrenme Geçmişi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadEvents) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadEvents()
            }
        }
    }
    
    private func loadEvents() {
        isLoading = true
        Task {
            let loaded = ArgusLedger.shared.loadLearningEvents(limit: 50)
            await MainActor.run {
                self.events = loaded
                self.isLoading = false
            }
        }
    }
}

// MARK: - Learning Event Card View
struct LearningEventCardView: View {
    let event: LearningEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Timestamp + Regime
            HStack {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let regime = event.regime {
                    Text(regime)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(regimeColor(regime).opacity(0.2))
                        .foregroundStyle(regimeColor(regime))
                        .clipShape(Capsule())
                }
            }
            
            // Weight Deltas
            VStack(alignment: .leading, spacing: 6) {
                ForEach(event.weightDeltas.sorted(by: { abs($0.value) > abs($1.value) }), id: \.key) { module, delta in
                    HStack {
                        Text(moduleIcon(module))
                            .font(.caption)
                        Text(module)
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        // Old → New
                        let oldW = event.oldWeights[module] ?? 0
                        let newW = event.newWeights[module] ?? 0
                        Text(String(format: "%.2f → %.2f", oldW, newW))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Delta Badge
                        Text(String(format: "%+.2f", delta))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(delta >= 0 ? .green : .red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(delta >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            
            Divider()
            
            // Reason
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                
                Text(event.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Metadata
            HStack {
                Label("\(event.windowDays) gün", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Label("\(event.sampleSize) karar", systemImage: "chart.bar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                if let metric = event.triggerMetric, let value = event.triggerValue {
                    Text("| \(metric): \(String(format: "%.0f%%", value * 100))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: event.timestamp)
    }
    
    private func regimeColor(_ regime: String) -> Color {
        switch regime.lowercased() {
        case "trend": return .green
        case "chop": return .orange
        case "riskoff", "risk-off": return .red
        case "neutral": return .gray
        default: return .blue
        }
    }
    
    private func moduleIcon(_ module: String) -> String {
        switch module.lowercased() {
        case "orion": return "📊"
        case "atlas": return "💰"
        case "aether": return "🌍"
        case "hermes": return "📰"
        case "athena": return "🧠"
        case "demeter": return "🌾"
        case "phoenix": return "🔥"
        default: return "📈"
        }
    }
}

// MARK: - Preview
#Preview {
    ObservatoryLearningView()
}
