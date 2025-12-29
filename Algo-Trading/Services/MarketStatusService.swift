import Foundation

enum MarketStatus {
    case open
    case closed(reason: String)
    case preMarket
    case afterHours
}

class MarketStatusService {
    static let shared = MarketStatusService()
    
    private let calendar = Calendar(identifier: .gregorian)
    private let timeZone = TimeZone(identifier: "America/New_York")!
    
    // US Market Hours (ET)
    private let marketOpenHour = 9
    private let marketOpenMinute = 30
    private let marketCloseHour = 16
    private let marketCloseMinute = 0
    
    // Public Checker
    func getMarketStatus() -> MarketStatus {
        let now = Date()
        
        // 1. Check Weekend
        if isWeekend(now) {
            return .closed(reason: "Haftasonu")
        }
        
        // 2. Check Time in NYC
        let components = calendar.dateComponents(in: timeZone, from: now)
        guard let hour = components.hour, let minute = components.minute else {
            return .closed(reason: "Zaman Hatası")
        }
        
        let currentMinutes = hour * 60 + minute
        let openMinutes = marketOpenHour * 60 + marketOpenMinute
        let closeMinutes = marketCloseHour * 60 + marketCloseMinute
        
        if currentMinutes < openMinutes {
            // Early Morning
            if currentMinutes >= (4 * 60) { // Premarket starts 4:00 AM usually
                return .preMarket
            }
            return .closed(reason: "Piyasa Açılmadı")
        } else if currentMinutes >= closeMinutes {
            if currentMinutes < (20 * 60) { // Afterhours until 8:00 PM
                return .afterHours
            }
            return .closed(reason: "Piyasa Kapandı")
        }
        
        return .open
    }
    
    func canTrade() -> Bool {
        // Strict Mode: Only Open Market
        // User requested "Asla alım satım yapamasın piyasa kapalı iken"
        switch getMarketStatus() {
        case .open: return true
        default: return false
        }
    }
    
    private func isWeekend(_ date: Date) -> Bool {
        let components = calendar.dateComponents(in: timeZone, from: date)
        // 1 = Sunday, 7 = Saturday
        return components.weekday == 1 || components.weekday == 7
    }
    
    // Formatted Time for UI
    func getNYTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
