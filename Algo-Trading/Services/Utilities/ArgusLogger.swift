import Foundation

// MARK: - Argus Logger
/// Centralized logging system for the entire application.
/// Replaces scattered print statements with structured, rigorous logging.
/// Supports log levels, categorization, and optional persistence.

actor ArgusLogger {
    static let shared = ArgusLogger()
    
    // MARK: - Configuration
    private var isEnabled: Bool = true
    #if DEBUG
    private var minLogLevel: LogLevel = .debug
    #else
    private var minLogLevel: LogLevel = .info
    #endif
    
    // In-memory buffer for UI display (e.g. Debug Console)
    private var recentLogs: [ArgusLogEntry] = []
    private let maxBufferSize = 200
    
    enum LogLevel: Int, Comparable, Codable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "🚨"
            case .critical: return "🔥"
            }
        }
        
        var label: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "FATAL"
            }
        }
    }
    
    private init() {}
    
    // MARK: - Public API
    
    func log(_ message: String, level: LogLevel, category: String, metadata: [String: String]? = nil) {
        guard isEnabled, level >= minLogLevel else { return }
        
        let entry = ArgusLogEntry(
            timestamp: Date(),
            level: level,
            category: category.uppercased(),
            message: message,
            metadata: metadata
        )
        
        // 1. Add to Buffer
        recentLogs.append(entry)
        if recentLogs.count > maxBufferSize {
            recentLogs.removeFirst()
        }
        
        // 2. Console Output (Structured)
        // Format: [HH:mm:ss] ℹ️ [CATEGORY] Message | {metadata}
        let timeStr = DateFormatter.localizedString(from: entry.timestamp, dateStyle: .none, timeStyle: .medium)
        var consoleMsg = "[\(timeStr)] \(level.emoji) [\(entry.category)] \(message)"
        
        if let metadata = metadata, !metadata.isEmpty {
            consoleMsg += " | \(metadata.description)"
        }
        
        print(consoleMsg)
    }
    
    // Convenience Methods
    func debug(_ message: String, category: String, metadata: [String: String]? = nil) {
        log(message, level: .debug, category: category, metadata: metadata)
    }
    
    func info(_ message: String, category: String, metadata: [String: String]? = nil) {
        log(message, level: .info, category: category, metadata: metadata)
    }
    
    func warn(_ message: String, category: String, metadata: [String: String]? = nil) {
        log(message, level: .warning, category: category, metadata: metadata)
    }
    
    func error(_ message: String, category: String, error: Error? = nil, metadata: [String: String]? = nil) {
        var meta = metadata ?? [:]
        if let err = error {
            meta["error_details"] = err.localizedDescription
        }
        log(message, level: .error, category: category, metadata: meta)
    }
    
    // MARK: - Access
    func getRecentLogs() -> [ArgusLogEntry] {
        return recentLogs
    }
    
    func clearLogs() {
        recentLogs.removeAll()
    }
}

struct ArgusLogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: ArgusLogger.LogLevel
    let category: String
    let message: String
    let metadata: [String: String]?
}
