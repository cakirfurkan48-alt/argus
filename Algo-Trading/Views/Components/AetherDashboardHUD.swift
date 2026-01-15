import SwiftUI

struct AetherDashboardHUD: View {
    let rating: MacroEnvironmentRating?
    let onTap: () -> Void
    
    // Animation States
    @State private var animateRings: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background Gradient Mesh
                LinearGradient(
                    colors: [Color(hex: "0a1220"), Color(hex: "05080f")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                
                if let r = rating {
                    HStack(spacing: 20) {
                        // MARK: - Central Score (Big Reactor)
                        ZStack {
                            // Outer Glow
                            Circle()
                                .fill(scoreColor(r.numericScore).opacity(0.1))
                                .frame(width: 90, height: 90)
                                .blur(radius: 10)
                            
                            // Progress Ring Background
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            // Active Progress Ring
                            Circle()
                                .trim(from: 0, to: animateRings ? r.numericScore / 100 : 0)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [scoreColor(r.numericScore).opacity(0.5), scoreColor(r.numericScore)]),
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 1.5), value: animateRings)
                            
                            // Inner Data
                            VStack(spacing: 2) {
                                Text("\(Int(r.numericScore))")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: scoreColor(r.numericScore).opacity(0.5), radius: 5)
                                
                                Text(r.regime.displayName.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(scoreColor(r.numericScore))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                            }
                        }
                        
                        // MARK: - 3-Part Tachometer (Leading / Coincident / Lagging)
                        VStack(spacing: 12) {
                            // Header
                            HStack {
                                Image(systemName: "globe.americas.fill")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                Text("AETHER MACRO SYSTEM")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .tracking(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack(spacing: 12) {
                                // 1. Leading (Öncü)
                                MacroGauge(
                                    label: "LEADING",
                                    score: r.leadingScore ?? 50,
                                    color: .green,
                                    icon: "binoculars.fill",
                                    animate: animateRings
                                )
                                
                                // 2. Coincident (Eşzamanlı)
                                MacroGauge(
                                    label: "COINCIDENT",
                                    score: r.coincidentScore ?? 50,
                                    color: .yellow,
                                    icon: "waveform.path.ecg",
                                    animate: animateRings
                                )
                                
                                // 3. Lagging (Gecikmeli)
                                MacroGauge(
                                    label: "LAGGING",
                                    score: r.laggingScore ?? 50,
                                    color: .red,
                                    icon: "rearview.camera.fill",
                                    animate: animateRings
                                )
                            }
                        }
                    }
                    .padding(16)
                } else {
                    // Loading / Empty State
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.cyan)
                        Text("Aether Atmosfer Verisi İndiriliyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .frame(height: 130)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateRings = true
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 60 { return .green }
        if score >= 40 { return .yellow }
        return .red
    }
}

// Subcomponent: Individual Macro Gauge (Semi-Circle)
struct MacroGauge: View {
    let label: String
    let score: Double
    let color: Color
    let icon: String
    let animate: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(90)) // Yarım daire üstte olsun diye değil, gauge mantığı
                    .offset(y: 10) // Yarım daire görünümü için
                
                // Fill
                Circle()
                    .trim(from: 0.5, to: 0.5 + (animate ? (score / 100) * 0.5 : 0))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.3), color]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(180)) // Soldan başlasın
                    .animation(.easeOut(duration: 1.0).delay(0.2), value: animate)
                    .offset(y: 10)
                
                // Icon/Score in center
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(color)
                        .offset(y: -5)
                    Text("\(Int(score))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 35) // Cut off bottom
            
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}

// Preview Provider
struct AetherDashboardHUD_Previews: PreviewProvider {
    static var previews: some View {
        let mockRating = MacroEnvironmentRating(
            equityRiskScore: 70, volatilityScore: 80, safeHavenScore: 60, cryptoRiskScore: 85, interestRateScore: 50, currencyScore: 60,
            inflationScore: 40, laborScore: 80, growthScore: 70, creditSpreadScore: 90, claimsScore: 85,
            leadingScore: 82, coincidentScore: 65, laggingScore: 45,
            leadingContribution: 0.4, coincidentContribution: 0.3, laggingContribution: 0.3,
            numericScore: 78, letterGrade: "B+", regime: .riskOn, summary: "Pozitif", details: "Detay"
        )
        
        AetherDashboardHUD(rating: mockRating) {}
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color.black)
    }
}
