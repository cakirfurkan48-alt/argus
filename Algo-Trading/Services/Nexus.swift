import Foundation
import Combine

// MARK: - Nexus Topics & Events
enum NexusTopic {
    case marketRegimeChanged    // Demeter -> Vortex
    case planUpdated           // Vortex -> UI, Chiron
    case tradeExecuted         // Executor -> Vortex, UI
    case manualOverride        // UI -> Vortex
    case analysisUpdated       // Orion/Atlas -> Vortex
}

struct NexusEvent {
    let id: UUID = UUID()
    let timestamp: Date = Date()
    let topic: NexusTopic
    let payload: [String: Any]?
    let message: String?
}

// MARK: - Nexus (The Orchestrator)
/// System-wide Event Bus to decouple components while ensuring synchronization.
class Nexus {
    static let shared = Nexus()
    
    private let eventSubject = PassthroughSubject<NexusEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        print("🌪️ Nexus Orchestrator Initialized")
    }
    
    // MARK: - API
    
    func publish(topic: NexusTopic, payload: [String: Any]? = nil, message: String? = nil) {
        let event = NexusEvent(topic: topic, payload: payload, message: message)
        // Log critical events
        if topic == .manualOverride || topic == .planUpdated {
            print("🌪️ Nexus Event: [\(topic)] - \(message ?? "")")
        }
        eventSubject.send(event)
    }
    
    func observe(topic: NexusTopic) -> AnyPublisher<NexusEvent, Never> {
        return eventSubject
            .filter { $0.topic == topic }
            .eraseToAnyPublisher()
    }
    
    func observeAll() -> AnyPublisher<NexusEvent, Never> {
        return eventSubject.eraseToAnyPublisher()
    }
}
