import SwiftUI

struct SystemInfoCard: View {
    let entity: ArgusSystemEntity
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }
            
            GlassCard(cornerRadius: 24, brightness: 0.1) {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: entity.icon)
                            .font(.title)
                            .foregroundColor(color(for: entity))
                        
                        Text(entity.rawValue.uppercased())
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button { withAnimation { isPresented = false } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Description
                    Text(entity.description)
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                    
                    // Stats / Traits handled generically or customized logic below
                    HStack(spacing: 16) {
                        trait(icon: "brain.head.profile", label: "AI Modülü")
                        trait(icon: "lock.shield", label: "Aktif")
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: 340)
            .shadow(color: color(for: entity).opacity(0.3), radius: 20)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private func color(for entity: ArgusSystemEntity) -> Color {
        // Map string colors to Color
        switch entity {
        case .argus, .corse, .atlas: return .blue
        case .aether: return .cyan
        case .orion, .pulse: return .purple
        case .chronos, .hermes: return .orange
        case .shield: return .green
        case .poseidon: return .indigo
        case .council: return .yellow
        }
    }
    
    private func trait(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
                .bold()
        }
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .foregroundColor(.white)
    }
}
