import SwiftUI

struct ChironDetailView: View {
    // State
    @State private var selectedEngine: AutoPilotEngine = .corse
    @State private var corseWeights: ChironModuleWeights?
    @State private var pulseWeights: ChironModuleWeights?
    @State private var learningEvents: [ChironLearningEvent] = []
    @State private var isAnalyzing = false
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.tint)
                            .shadow(color: Theme.tint.opacity(0.3), radius: 10)
                        
                        Text("Chiron 2.0 - El Patrón")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text("Symbol + Engine bazlı öğrenme sistemi")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Engine Selector (NEW)
                    HStack(spacing: 0) {
                        EngineTab(title: "CORSE 🐢", isSelected: selectedEngine == .corse) {
                            withAnimation { selectedEngine = .corse }
                        }
                        EngineTab(title: "PULSE ⚡", isSelected: selectedEngine == .pulse) {
                            withAnimation { selectedEngine = .pulse }
                        }
                    }
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // MARK: - Active Weights Display
                    if let weights = selectedEngine == .corse ? corseWeights : pulseWeights {
                        WeightsCard(engine: selectedEngine, weights: weights)
                    } else {
                        // Show defaults with explanation
                        VStack(spacing: 8) {
                            Text("Varsayılan Ağırlıklar Aktif")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("Henüz bu engine için öğrenilmiş ağırlık yok. Sistem varsayılan değerlerle çalışıyor ve trade'ler tamamlandıkça öğrenecek.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            // Show defaults anyway
                            let defaults = selectedEngine == .corse ? ChironModuleWeights.defaultCorse : ChironModuleWeights.defaultPulse
                            WeightsCard(engine: selectedEngine, weights: defaults)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // MARK: - Learning Timeline
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.green)
                            Text("Öğrenme Geçmişi")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Trigger Analysis Button
                            Button(action: triggerAnalysis) {
                                if isAnalyzing {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Label("Analiz", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                            }
                            .disabled(isAnalyzing)
                            .foregroundColor(.green)
                        }
                        
                        if learningEvents.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "questionmark.circle")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("Henüz öğrenme kaydı yok")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("Trade'ler kapandıkça sistem otomatik öğrenecek ve burada gösterilecek.")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(learningEvents.prefix(10)) { event in
                                LearningEventRow(event: event)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitle("Chiron Insights", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        // Load from ChironWeightStore (NEW)
        corseWeights = await ChironWeightStore.shared.getWeights(symbol: "DEFAULT", engine: .corse)
        pulseWeights = await ChironWeightStore.shared.getWeights(symbol: "DEFAULT", engine: .pulse)
        
        // Load learning events from Data Lake
        learningEvents = await ChironDataLakeService.shared.loadLearningEvents()
    }
    
    private func triggerAnalysis() {
        isAnalyzing = true
        Task {
            await ChironLearningJob.shared.runFullAnalysis()
            await loadData()
            isAnalyzing = false
        }
    }
}

// MARK: - Engine Tab
struct EngineTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : .gray)
                
                Rectangle()
                    .fill(isSelected ? (title.contains("CORSE") ? Color.blue : Color.purple) : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Weights Card
struct WeightsCard: View {
    let engine: AutoPilotEngine
    let weights: ChironModuleWeights
    
    var engineColor: Color {
        engine == .corse ? .blue : .purple
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(engine == .corse ? "CORSE Ağırlıkları 🐢" : "PULSE Ağırlıkları ⚡")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Güven: %\(Int(weights.confidence * 100))")
                    .font(.caption)
                    .foregroundColor(weights.confidence > 0.7 ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(weights.confidence > 0.7 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Weights Grid
            VStack(spacing: 10) {
                WeightBar(label: "Orion (Teknik)", value: weights.orion, color: .cyan, description: "Trend & Momentum")
                WeightBar(label: "Atlas (Temel)", value: weights.atlas, color: .blue, description: "Fundamentals")
                WeightBar(label: "Phoenix (Fiyat)", value: weights.phoenix, color: .red, description: "Price Action")
                WeightBar(label: "Aether (Makro)", value: weights.aether, color: .orange, description: "Market Regime")
                WeightBar(label: "Hermes (Haber)", value: weights.hermes, color: .purple, description: "News Sentiment")
                WeightBar(label: "Cronos (Zaman)", value: weights.cronos, color: .gray, description: "Timing")
            }
            
            // Reasoning
            if !weights.reasoning.isEmpty {
                Divider().background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Son Güncelleme Nedeni:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(weights.reasoning)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                }
            }
            
            // Update Time
            Text("Son güncelleme: \(weights.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(engineColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(engineColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Weight Bar
struct WeightBar: View {
    let label: String
    let value: Double
    let color: Color
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 100, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(1.0, value)))
                }
            }
            .frame(height: 8)
            
            Text("%\(Int(value * 100))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// Learning Event Row
struct LearningEventRow: View {
    let event: ChironLearningEvent
    
    var eventIcon: String {
        switch event.eventType {
        case .weightUpdate: return "slider.horizontal.3"
        case .ruleAdded: return "plus.circle"
        case .ruleRemoved: return "minus.circle"
        case .analysisCompleted: return "checkmark.circle"
        case .anomalyDetected: return "exclamationmark.triangle"
        }
    }
    
    var eventColor: Color {
        switch event.eventType {
        case .weightUpdate: return .blue
        case .ruleAdded: return .green
        case .ruleRemoved: return .red
        case .analysisCompleted: return .cyan
        case .anomalyDetected: return .orange
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: eventIcon)
                .foregroundColor(eventColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let symbol = event.symbol {
                        Text(symbol)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                    }
                    
                    if let engine = event.engine {
                        Text(engine == .corse ? "🐢" : "⚡")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text(event.date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                if event.confidence > 0.7 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                        Text("Güven: %\(Int(event.confidence * 100))")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding(8)
        .background(eventColor.opacity(0.1))
        .cornerRadius(8)
    }
}
