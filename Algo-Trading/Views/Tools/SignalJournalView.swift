import SwiftUI

struct SignalJournalView: View {
    @ObservedObject var tracker = SignalTrackerService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("Canlı Sinyal Günlüğü 📡")
                        .font(.title2)
                        .bold()
                    Text("Argus'un geçmiş tahminleri ve gerçek sonuçları")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                if tracker.journalEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "notebook")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Henüz takibe alınan sinyal yok.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(tracker.journalEntries) { entry in
                            SignalJournalCard(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Sinyal Karnesi")
    }
}

struct SignalJournalCard: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Symbol & Date
            HStack {
                Text(entry.symbol)
                    .font(.headline)
                    .bold()
                Spacer()
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Snapshot Data
            HStack {
                // Price & Action
                VStack(alignment: .leading) {
                    Text("Giriş: $\(String(format: "%.2f", entry.entryPrice))")
                        .font(.callout)
                    
                    HStack {
                        // Badge Fallback since Action is String now
                        Text(entry.action)
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(entry.action == "BUY" ? Theme.positive.opacity(0.2) : Theme.negative.opacity(0.2))
                            .foregroundColor(entry.action == "BUY" ? Theme.positive : Theme.negative)
                            .cornerRadius(8)
                        
                        Text("(\(entry.status.rawValue))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Outcome
                if let pnl = entry.outcome {
                    VStack(alignment: .trailing) {
                        Text("Sonuç")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(String(format: "%.2f%%", pnl))
                        }
                        .font(.title3)
                        .bold()
                        .foregroundColor(pnl >= 0 ? Theme.positive : Theme.negative)
                    }
                } else {
                    Text("Hesaplanıyor...")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .contextMenu {
            Button(role: .destructive) {
                SignalTrackerService.shared.deleteEntry(id: entry.id)
            } label: {
                Label("Kaydı Sil", systemImage: "trash")
            }
        }
    }
}
