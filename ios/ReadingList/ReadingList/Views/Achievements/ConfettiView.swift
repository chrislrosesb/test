import SwiftUI

// MARK: - Confetti particle system using Canvas + TimelineView

struct ConfettiView: View {
    let level: ConfettiLevel

    private let particles: [ConfettiParticle]

    init(level: ConfettiLevel) {
        self.level = level
        let count = level == .heavy ? 80 : 40
        self.particles = (0..<count).map { _ in ConfettiParticle() }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let elapsed = (now - p.birth).truncatingRemainder(dividingBy: p.period)
                    let t = elapsed / p.period  // 0...1 through each cycle

                    let x = p.startX * size.width + p.driftX * elapsed * size.width
                    let y = t * (size.height + 40) - 20
                    let angle = p.rotStart + p.rotSpeed * elapsed
                    let alpha = t < 0.15 ? t / 0.15 : t > 0.75 ? (1 - t) / 0.25 : 1.0

                    ctx.opacity = max(0, min(1, alpha))

                    var transform = CGAffineTransform(translationX: x, y: y)
                        .rotated(by: angle)
                    ctx.concatenate(transform)

                    let rect = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(p.color))

                    // Reset transform so next particle starts fresh
                    transform = transform.inverted()
                    ctx.concatenate(transform)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ConfettiParticle {
    let startX: Double       // 0...1 relative to width
    let driftX: Double       // horizontal drift per second (fraction of width)
    let period: Double       // time to fall full height (seconds)
    let birth: Double        // start time offset (staggered)
    let rotStart: Double     // initial rotation (radians)
    let rotSpeed: Double     // rotation speed (rad/sec)
    let w: Double            // particle width
    let h: Double            // particle height
    let color: Color

    private static let palette: [Color] = [
        .yellow, .orange, .pink, .purple, .cyan, .green, .red, .blue,
        Color(red: 1, green: 0.84, blue: 0),   // gold
        Color(red: 0.8, green: 0.2, blue: 0.8), // violet
    ]

    init() {
        startX   = Double.random(in: 0...1)
        driftX   = Double.random(in: -0.06...0.06)
        period   = Double.random(in: 1.8...3.2)
        birth    = TimeInterval(Date.timeIntervalSinceReferenceDate) - Double.random(in: 0...3)
        rotStart = Double.random(in: 0...(2 * .pi))
        rotSpeed = Double.random(in: -3...3)
        w        = Double.random(in: 6...11)
        h        = Double.random(in: 4...7)
        color    = Self.palette.randomElement()!
    }
}
