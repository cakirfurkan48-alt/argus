import Foundation
import Combine

enum HealthStatus: String, Codable {
    case healthy = "Sağlıklı"
    case degraded = "Riskli"
    case critical = "Kritik"
    case unknown = "Bilinmiyor"
}

struct DataHealthReport: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    var overallStatus: HealthStatus
    var apiLatency: Double // ms
    var dataFreshness: Double // seconds since last update
    var activeProvider: String
    var errors: [String]
    
    // Safety Check for AutoPilot
    var isSafeToTrade: Bool {
        return overallStatus == .healthy && apiLatency < 2000 && dataFreshness < 60
    }
}

class DataHealthService: ObservableObject {
    static let shared = DataHealthService()
    
    @Published var currentReport: DataHealthReport
    @Published var history: [DataHealthReport] = []
    
    private init() {
        self.currentReport = DataHealthReport(
            timestamp: Date(),
            overallStatus: .unknown,
            apiLatency: 0,
            dataFreshness: 0,
            activeProvider: "Unknown",
            errors: []
        )
    }
    
    func logHeartbeat(latency: Double, provider: String, errors: [String] = []) {
        var status: HealthStatus = .healthy
        
        if !errors.isEmpty || latency > 5000 {
            status = .critical
        } else if latency > 1500 {
            status = .degraded
        }
        
        // Freshness check (simplified, effectively just "now")
        // In real app, we'd compare against last quote time.
        
        let report = DataHealthReport(
            timestamp: Date(),
            overallStatus: status,
            apiLatency: latency,
            dataFreshness: 0, // Reset on heartbeat
            activeProvider: provider,
            errors: errors
        )
        
        DispatchQueue.main.async {
            self.currentReport = report
            self.history.append(report)
            if self.history.count > 50 { self.history.removeFirst() }
        }
    }
}
