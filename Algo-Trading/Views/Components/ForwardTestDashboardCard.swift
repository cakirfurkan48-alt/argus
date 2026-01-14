import SwiftUI

// MARK: - Forward Test Dashboard Card
/// Forward test sonuçlarını gösteren Chiron UI bileşeni
struct ForwardTestDashboardCard: View {
    @State private var stats: ForwardTestStats = .empty
    @State private var pendingTests: [PendingForwardTest] = []
    @State private var recentResults: [ForwardTestResult] = []
    @State private var isProcessing = false
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.purple)
                Text("Forward Test")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Process Button
                Button(action: runProcessing) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("Dogrula")
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }
                .disabled(isProcessing)
                
                // Clear Button
                Button(action: clearAllData) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Yukleniyor...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                // Stats Summary
                HStack(spacing: 24) {
                    FTStatBox(title: "Bekleyen", value: "\(pendingTests.count)", color: .orange)
                    FTStatBox(title: "Dogrulanan", value: "\(stats.totalTests)", color: .green)
                    FTStatBox(title: "Isabet", value: "%\(Int(stats.hitRate * 100))", color: stats.hitRate >= 0.5 ? .green : .red)
                }
                
                // Hit Rate Bars
                if stats.totalTests > 0 {
                    VStack(spacing: 8) {
                        HitRateBar(label: "Prometheus", rate: stats.prometheusHitRate, color: .cyan)
                        HitRateBar(label: "Argus", rate: stats.argusHitRate, color: .purple)
                    }
                    .padding(.top, 8)
                }
                
                // Recent Results
                if !recentResults.isEmpty {
                    Divider().background(Color.gray.opacity(0.3))
                    
                    Text("Son Dogrulamalar")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    ForEach(recentResults.prefix(3)) { result in
                        ForwardTestResultRow(result: result)
                    }
                }
                
                // Pending Tests
                if !pendingTests.isEmpty {
                    Divider().background(Color.gray.opacity(0.3))
                    
                    HStack {
                        Text("Bekleyen Testler")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(pendingTests.filter { $0.isMature }.count) olgun")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    ForEach(pendingTests.prefix(3)) { test in
                        PendingTestRow(test: test)
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        stats = await ForwardTestProcessor.shared.calculateStats()
        pendingTests = await ForwardTestProcessor.shared.getPendingTests()
        
        print("ForwardTest UI: \(pendingTests.count) bekleyen test, \(stats.totalTests) dogrulanan")
        
        // Load recent results from disk
        let resultsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ForwardTestResults.json")
        if let data = try? Data(contentsOf: resultsPath),
           let results = try? JSONDecoder().decode([ForwardTestResult].self, from: data) {
            recentResults = Array(results.suffix(5).reversed())
            print("ForwardTest UI: \(results.count) kayitli sonuc")
        }
        
        isLoading = false
    }
    
    private func runProcessing() {
        isProcessing = true
        Task {
            print("ForwardTest: Processing basladi...")
            let results = await ForwardTestProcessor.shared.processMaturedTests()
            print("ForwardTest: \(results.count) test islendi")
            
            // Save results
            if !results.isEmpty {
                let resultsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("ForwardTestResults.json")
                
                var existing: [ForwardTestResult] = []
                if let data = try? Data(contentsOf: resultsPath),
                   let decoded = try? JSONDecoder().decode([ForwardTestResult].self, from: data) {
                    existing = decoded
                }
                existing.append(contentsOf: results)
                
                // Keep last 500
                if existing.count > 500 {
                    existing = Array(existing.suffix(500))
                }
                
                if let data = try? JSONEncoder().encode(existing) {
                    try? data.write(to: resultsPath)
                }
            }
            
            await loadData()
            isProcessing = false
        }
    }
    
    private func clearAllData() {
        Task {
            print("ForwardTest: Tum veriler temizleniyor...")
            await ForwardTestLedger.shared.cleanupProcessedEvents()
            
            // Sonuc dosyasini da sil
            let resultsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("ForwardTestResults.json")
            try? FileManager.default.removeItem(at: resultsPath)
            
            await loadData()
            print("ForwardTest: Temizlik tamamlandi")
        }
    }
}

// MARK: - Supporting Views

struct FTStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct HitRateBar: View {
    let label: String
    let rate: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 70, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(1.0, rate)))
                }
            }
            .frame(height: 6)
            
            Text("%\(Int(rate * 100))")
                .font(.caption)
                .bold()
                .foregroundColor(rate >= 0.5 ? .green : .red)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

struct ForwardTestResultRow: View {
    let result: ForwardTestResult
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.wasCorrect ? .green : .red)
                .font(.caption)
            
            Text(result.symbol)
                .font(.caption)
                .bold()
                .foregroundColor(.white)
            
            Text(result.testType == .prometheusforecast ? "P" : "A")
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(result.testType == .prometheusforecast ? Color.cyan.opacity(0.3) : Color.purple.opacity(0.3))
                .cornerRadius(4)
            
            Spacer()
            
            Text(String(format: "%+.1f%%", result.actualChange))
                .font(.caption)
                .foregroundColor(result.actualChange >= 0 ? .green : .red)
        }
    }
}

struct PendingTestRow: View {
    let test: PendingForwardTest
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: test.isMature ? "clock.badge.checkmark" : "clock")
                .foregroundColor(test.isMature ? .green : .orange)
                .font(.caption)
            
            Text(test.symbol)
                .font(.caption)
                .foregroundColor(.white)
            
            Text(test.testType == .prometheusforecast ? "P" : "A")
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(test.testType == .prometheusforecast ? Color.cyan.opacity(0.3) : Color.purple.opacity(0.3))
                .cornerRadius(4)
            
            Spacer()
            
            if test.isMature {
                Text("Hazir")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("\(test.daysUntilMature) gun")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
}
