import SwiftUI

/// A Netflix-Quality Cinematic Intro for Argus.
/// Features: Canvas Rendering, Particle System, Chromatic Aberration, Typography.
struct ArgusCinematicIntro: View {
    var onFinished: () -> Void
    
    // Animation State
    @State private var startTime: Date = Date()
    
    // Haptics
    private let engineHaptics = UIImpactFeedbackGenerator(style: .soft)
    private let boomHaptics = UIImpactFeedbackGenerator(style: .rigid)
    
    var body: some View {
        TimelineView(.animation) { timeline in
            CinematicRenderer(time: timeline.date.timeIntervalSince(startTime))
                .onChange(of: timeline.date) { newDate in
                    let t = newDate.timeIntervalSince(startTime)
                    
                    // Haptic Triggers
                    if t > 0.5 && t < 0.6 { engineHaptics.impactOccurred() } // Typography
                    if t > 3.0 && t < 3.1 { engineHaptics.impactOccurred() } // Charge
                    if t > 4.5 && t < 4.6 { boomHaptics.impactOccurred() }   // BOOM (Warp)
                    
                    if t > 5.5 {
                        onFinished()
                    }
                }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            startTime = Date()
            engineHaptics.prepare()
            boomHaptics.prepare()
        }
    }
}

/// Extracted Renderer to solve Shader/Canvas Type Inference issues
struct CinematicRenderer: View {
    let time: Double
    
    var body: some View {
        Canvas { context, size in
            let frame = Int(time * 60)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            
            // MARK: - Orchestration Logic (The Director)
            // 0.0s - 0.5s: Void
            // 0.5s - 2.5s: Typography
            // 2.5s - 4.5s: Formation & Pulse
            // 4.5s - 5.5s: Warp
            
            // 1. Typography Phase (ARGUS text)
            if time > 0.5 && time < 3.0 {
                let textOpacity = time < 1.0 ? (time - 0.5) * 2 : (time > 2.5 ? (3.0 - time) * 2 : 1.0)
                let tracking = 5.0 + (Double(frame) * 0.1) // Letters drifting apart slowly
                
                let text = Text("ARGUS")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .tracking(tracking)
                    .foregroundColor(.white.opacity(textOpacity))
                
                // Add subtle glow
                context.addFilter(.shadow(color: .cyan.opacity(0.5), radius: 8))
                context.draw(text, at: center)
                
                // Reset filters for next layer
                context.addFilter(.shadow(color: .clear, radius: 0))
            }
            
            // 2. The Eye Formation (Particles)
            if time > 2.0 {
                // Draw the Eye Shape with "Electric" effect
                // We simulate "Living Aether" by shaking the path slightly
                let shake = time > 3.5 ? sin(time * 50) * 2 : 0
                
                context.translateBy(x: center.x, y: center.y)
                context.translateBy(x: shake, y: 0) // Glitch shake
                
                // Chromatic Aberration Effect (RGB Split)
                // Draw Red Channel slightly offset
                // Chromatic Aberration Effect (RGB Split)
                // Draw Red Channel slightly offset
                if time > 3.5 {
                    var redContext = context
                    redContext.translateBy(x: -4, y: 0)
                    drawEye(context: redContext, color: .red.opacity(0.5), scale: 1.0)
                    
                    var blueContext = context
                    blueContext.translateBy(x: 4, y: 0)
                    drawEye(context: blueContext, color: .blue.opacity(0.5), scale: 1.0)
                } 
                
                // Main White/Cyan Channel
                drawEye(context: context, color: .white, scale: 1.0)
                
                // Outer Glow
                if time > 3.0 {
                    let pulse = abs(sin(time * 5))
                    drawEye(context: context, color: .cyan.opacity(0.4 * pulse), scale: 1.1)
                }
            }
            
            // 3. Hyperspace Warp (Particle Starfield)
            if time > 4.0 {
                let warpProgress = time - 4.0 // 0.0 to 1.5
                
                // Speed increases exponentially
                let speed = pow(warpProgress, 3) * 50
                
                // Draw thousands of stars flying past
                // We simulate this statelesly for Canvas performance by hashing frame index
                // This creates a deterministic but chaotic "fly through" effect
                // Simulating 200 "stars"
                for i in 0..<200 {
                    // Deterministic random positions based on index
                    let angle = Double(i * 137) // Golden angle to disperse
                    let distBase = Double(i % 50) * 10
                    
                    // Distance moves closer to 0 (center) inversed, or outward
                    // For Warp, we want things starting center and flying OUT
                    let currentDist = (distBase + (Double(frame) * speed * 0.5)).truncatingRemainder(dividingBy: 1000)
                    
                    let x = cos(angle) * currentDist
                    let y = sin(angle) * currentDist
                    
                    // Trail effect (lenghts increases with speed)
                    let length = speed * 2
                    
                    let start = CGPoint(x: x, y: y)
                    let end = CGPoint(x: cos(angle) * (currentDist + length), y: sin(angle) * (currentDist + length))
                    
                    let opacity = min(1.0, currentDist / 200) // Fade in from center
                    
                    let path = Path { p in
                        p.move(to: start)
                        p.addLine(to: end)
                    }
                    
                    context.stroke(path, with: .color(.cyan.opacity(opacity)), lineWidth: 2)
                }
            }
        }
    }
    
    // MARK: - Helper Drawing
    func drawEye(context: GraphicsContext, color: Color, scale: Double) {
        let size = CGSize(width: 150 * scale, height: 150 * scale)
        let rect = CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height)
        
        var path = Path()
        
        // Triangle
        path.move(to: CGPoint(x: 0, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.8))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.8))
        path.closeSubpath()
        
        // Eye
        path.move(to: CGPoint(x: rect.minX * 0.6, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX * 0.6, y: 0), control: CGPoint(x: 0, y: rect.minY * 0.6))
        path.addQuadCurve(to: CGPoint(x: rect.minX * 0.6, y: 0), control: CGPoint(x: 0, y: rect.maxY * 0.6))
        
        // Pupil
        path.addEllipse(in: CGRect(x: -10, y: -10, width: 20, height: 20))
        
        context.stroke(path, with: .color(color), lineWidth: 4)
    }
}

#Preview {
    ArgusCinematicIntro(onFinished: {})
}
