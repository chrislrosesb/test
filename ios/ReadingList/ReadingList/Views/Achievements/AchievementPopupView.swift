import SwiftUI

struct AchievementPopupView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Confetti (behind card)
            if achievement.confettiLevel != .none {
                ConfettiView(level: achievement.confettiLevel)
                    .ignoresSafeArea()
            }

            // Tap-anywhere-to-dismiss overlay
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismissNow() }

            // Card
            VStack(spacing: 0) {
                // Procy
                ProcyView(mood: achievement.mood)
                    .frame(width: 148, height: 185)
                    .padding(.top, 8)

                // Text
                VStack(spacing: 6) {
                    Text(achievement.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text(achievement.subtitle)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)

                // Dismiss button
                Button {
                    dismissNow()
                } label: {
                    Text("Nice.")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(tintColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(width: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
            .scaleEffect(appeared ? 1.0 : 0.72)
            .opacity(appeared ? 1.0 : 0)
            .offset(y: appeared ? 0 : 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.62)) {
                appeared = true
            }
            // Auto-dismiss after 5s for .none confetti, 7s for others
            let delay: Double = achievement.confettiLevel == .none ? 5 : 7
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard appeared else { return }
                dismissNow()
            }
        }
    }

    private func dismissNow() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }

    private var tintColor: Color {
        switch achievement.mood {
        case .surprised: return .blue
        case .excited:   return .orange
        case .chaos:     return .purple
        }
    }
}
