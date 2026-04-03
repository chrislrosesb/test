import SwiftUI

// MARK: - Procy the Sloth

struct ProcyView: View {
    let mood: ProcyMood

    @State private var eyeScale: CGFloat = 0.6
    @State private var bodyBounce: CGFloat = 16
    @State private var headWobble: Double = 0
    @State private var armAngle: Double = 0
    @State private var showPartyHat: Bool = false
    @State private var hatBob: CGFloat = 0

    // Sloth palette
    private let bodyColor     = Color(red: 0.45, green: 0.38, blue: 0.29)
    private let headColor     = Color(red: 0.52, green: 0.45, blue: 0.36)
    private let faceMaskColor = Color(red: 0.84, green: 0.76, blue: 0.62)
    private let eyePatchColor = Color(red: 0.16, green: 0.10, blue: 0.05)
    private let earOuterColor = Color(red: 0.34, green: 0.27, blue: 0.18)
    private let noseColor     = Color(red: 0.18, green: 0.12, blue: 0.06)

    var body: some View {
        ZStack {
            // Arms (behind body and head)
            armView(side: -1)
            armView(side:  1)

            // Body
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(bodyColor)
                .frame(width: 80, height: 70)
                .offset(y: 38)

            // Ears (behind head)
            earView(side: -1)
            earView(side:  1)

            // Head
            Circle()
                .fill(headColor)
                .frame(width: 90)
                .offset(y: -18)

            // Face mask
            Ellipse()
                .fill(faceMaskColor)
                .frame(width: 56, height: 48)
                .offset(y: -14)

            // Eye patches (dark rings around eyes)
            Ellipse()
                .fill(eyePatchColor)
                .frame(width: 25, height: 19)
                .offset(x: -16, y: -24)
            Ellipse()
                .fill(eyePatchColor)
                .frame(width: 25, height: 19)
                .offset(x: 16, y: -24)

            // Eyes
            eyeView(xOff: -16, yOff: -24)
            eyeView(xOff:  16, yOff: -24)

            // Nose
            Ellipse()
                .fill(noseColor)
                .frame(width: 13, height: 8)
                .offset(y: -7)

            // Mouth
            mouthView

            // Party hat (chaos only)
            if showPartyHat {
                partyHatView
                    .offset(x: 4, y: -70 + hatBob)
            }
        }
        .frame(width: 148, height: 185)
        .offset(y: bodyBounce)
        .onAppear { startAnimation() }
    }

    // MARK: - Sub-views

    @ViewBuilder
    func armView(side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(bodyColor)
            .frame(width: 16, height: 50)
            .rotationEffect(
                .degrees(side * (18 - armAngle)),
                anchor: UnitPoint(x: 0.5, y: 0.05)
            )
            .offset(x: side * 46, y: 26)
    }

    @ViewBuilder
    func earView(side: CGFloat) -> some View {
        Circle()
            .fill(earOuterColor)
            .frame(width: 27)
            .offset(x: side * 42, y: -28)
        Circle()
            .fill(headColor)
            .frame(width: 15)
            .offset(x: side * 42, y: -28)
    }

    @ViewBuilder
    func eyeView(xOff: CGFloat, yOff: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 13, height: 13)
            Circle()
                .fill(eyePatchColor)
                .frame(width: 6, height: 6)
                .offset(y: mood == .surprised ? -1 : 1)
        }
        .scaleEffect(eyeScale)
        .offset(x: xOff, y: yOff)
    }

    @ViewBuilder
    var mouthView: some View {
        switch mood {
        case .surprised:
            // Little "O" mouth
            Circle()
                .stroke(noseColor, lineWidth: 2)
                .frame(width: 9, height: 9)
                .offset(y: 2)
        case .excited, .chaos:
            // Big happy arc
            Arc(startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
                .stroke(noseColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 22, height: 10)
                .offset(y: 2)
        }
    }

    @ViewBuilder
    var partyHatView: some View {
        ZStack {
            ProcyTriangle()
                .fill(
                    LinearGradient(
                        colors: [.yellow, .orange, .pink, .purple],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 34, height: 46)
            // Brim
            Capsule()
                .fill(Color.yellow.opacity(0.9))
                .frame(width: 38, height: 7)
                .offset(y: 23)
            // Star tip
            Image(systemName: "star.fill")
                .font(.system(size: 9))
                .foregroundStyle(.yellow)
                .offset(y: -27)
        }
        .rotationEffect(.degrees(-8))
    }

    // MARK: - Animation

    func startAnimation() {
        // Entrance spring
        withAnimation(.spring(response: 0.48, dampingFraction: 0.58)) {
            bodyBounce = 0
            eyeScale = 1.0
        }

        switch mood {
        case .surprised:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.38).delay(0.25)) {
                eyeScale = 1.48
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.5)) {
                bodyBounce = -6
            }

        case .excited:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4).delay(0.25)) {
                eyeScale = 1.2
                armAngle = 28
            }
            withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true).delay(0.35)) {
                headWobble = 11
            }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(0.15)) {
                bodyBounce = -11
            }

        case .chaos:
            showPartyHat = true
            withAnimation(.spring(response: 0.22, dampingFraction: 0.32).delay(0.2)) {
                eyeScale = 1.55
                armAngle = 62
            }
            withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true).delay(0.25)) {
                headWobble = 16
            }
            withAnimation(.easeInOut(duration: 0.38).repeatForever(autoreverses: true).delay(0.05)) {
                bodyBounce = -16
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                hatBob = -5
            }
        }
    }
}

// MARK: - Helpers

struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: rect.width / 2,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: clockwise
            )
        }
    }
}

struct ProcyTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to:    CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
