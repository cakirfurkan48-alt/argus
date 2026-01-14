import SwiftUI

struct ChironPerformanceView: View {
    @State private var decisionLogs: [ChironDecisionLog] = []
    @State private var moduleReliability: [String: Double] = [:]
    @State private var selectedTimeframe: String = "T+15m" // vs "T+60m"
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. Reliability Matrix (Heatmap)
            VStack(alignment: .leading, spacing: 10) {
                Text("Modül Güvenilirlik Matrisi")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    ReliabilityBadge(name: "Orion", score: moduleReliability["Orion"] ?? 1.0)
                    ReliabilityBadge(name: "Atlas", score: moduleReliability["Atlas"] ?? 1.0)
                    ReliabilityBadge(name: "Aether", score: moduleReliability["Aether"] ?? 1.0)
                    ReliabilityBadge(name: "Hermes", score: moduleReliability["Hermes"] ?? 1.0)
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            
            // 2. Decision Journal
            VStack(alignment: .leading) {
                Text("Karar Geçmişi (Canlı)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                if decisionLogs.isEmpty {
                    Text("Henüz tamamlanmış analiz sonucu yok.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(decisionLogs) { log in
                        DecisionLogCard(log: log)
                    }
                }
            }
        }
        .task {
            // Load data
            await loadJournal()
        }
    }
    
    private func loadJournal() async {
        decisionLogs = await ChironJournalService.shared.getLogs().sorted(by: { $0.timestamp > $1.timestamp })
        moduleReliability = await ChironJournalService.shared.getModuleReliability()
    }
}

struct ReliabilityBadge: View {
    let name: String
    let score: Double // 1.0 = Neutral, >1.0 = Good
    
    var color: Color {
        if score > 1.2 { return .green }
        if score < 0.8 { return .red }
        return .gray
    }
    
    var body: some View {
        VStack {
            Text(name)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(String(format: "%.1fx", score))
                .font(.caption)
                .bold()
                .foregroundColor(color)
        }
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct DecisionLogCard: View {
    let log: ChironDecisionLog
    
    var outcomeColor: Color {
        guard let res = log.resultT15 else { return .gray }
        return res.isSuccess ? .green : .red
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(log.symbol)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                    Text(log.finalAction)
                        .font(.caption)
                        .bold()
                        .padding(4)
                        .background(log.finalAction == "BUY" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(log.finalAction == "BUY" ? .green : .red)
                }
                Text(log.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if let res = log.resultT15 {
                VStack(alignment: .trailing) {
                    Text(String(format: "%+.2f%%", res.changePercent))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(outcomeColor)
                    Text("T+15 Sonuç")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else {
                Text("Bekleniyor...")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(log.resultT15?.isSuccess == true ? Color.green.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
