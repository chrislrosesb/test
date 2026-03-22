import SwiftUI

struct SignInView: View {
    @Environment(AuthViewModel.self) private var authVM

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo / header
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: authVM.isLoading)

                    Text("Reading List")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Sign in to access your library")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Form
                VStack(spacing: 16) {
                    glassField(icon: "envelope.fill") {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                            .foregroundStyle(.white)
                    }

                    glassField(icon: "lock.fill") {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { signIn() }
                            .foregroundStyle(.white)
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Button(action: signIn) {
                        HStack {
                            if authVM.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .disabled(email.isEmpty || password.isEmpty || authVM.isLoading)
                    .animation(.spring(duration: 0.3), value: authVM.isLoading)
                }
                .padding(.horizontal, 28)

                Spacer()
            }
        }
        .animation(.spring(duration: 0.4), value: authVM.errorMessage)
    }

    @ViewBuilder
    func glassField<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    func signIn() {
        focus = nil
        guard !email.isEmpty, !password.isEmpty else { return }
        Task { await authVM.signIn(email: email, password: password) }
    }
}
