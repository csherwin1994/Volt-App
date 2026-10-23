import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("localMode") private var localMode = false
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var isSocialLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    // Apple Sign In state
    @State private var currentNonce: String?

    private let supabase = SupabaseManager.shared

    enum Mode { case signIn, signUp }
    enum Field { case email, password, confirmPassword }

    var body: some View {
        ZStack {
            VoltColor.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Wordmark: gold square, mono caption, one big headline
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Rectangle().fill(VoltColor.accent).frame(width: 8, height: 8)
                            Text("VOLT · PERFORMANCE, TRACKED")
                                .font(VoltFont.mono(11)).tracking(0.9)
                                .foregroundStyle(VoltColor.labelSecondary)
                        }
                        Text(mode == .signIn ? "Welcome back." : "Start training.")
                            .font(VoltFont.sans(40)).tracking(-1.4)
                            .foregroundStyle(VoltColor.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, VoltSpacing.xxl)
                    .padding(.bottom, VoltSpacing.xl)

                    VoltSegmented(
                        options: [(value: Mode.signIn, label: "Sign in"), (value: Mode.signUp, label: "Create account")],
                        selection: Binding(get: { mode }, set: { mode = $0; errorMessage = nil })
                    )
                    .padding(.bottom, VoltSpacing.lg)

                    // Fields: mono label over an ink underline
                    VStack(spacing: VoltSpacing.md) {
                        inputField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            field: .email,
                            keyboard: .emailAddress,
                            contentType: .emailAddress
                        )
                        inputField(
                            label: "Password",
                            placeholder: "At least 6 characters",
                            text: $password,
                            field: .password,
                            isSecure: true,
                            contentType: mode == .signIn ? .password : .newPassword
                        )
                        if mode == .signUp {
                            inputField(
                                label: "Confirm password",
                                placeholder: "Repeat password",
                                text: $confirmPassword,
                                field: .confirmPassword,
                                isSecure: true,
                                contentType: .newPassword
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(VoltFont.mono(12)).tracking(0.3)
                            .foregroundStyle(VoltColor.danger)
                            .padding(.top, VoltSpacing.md)
                            .transition(.opacity)
                            .accessibilityAddTraits(.updatesFrequently)
                    }

                    VoltButton(
                        mode == .signIn ? "Sign In" : "Create Account",
                        isLoading: isLoading
                    ) {
                        Task { await submit() }
                    }
                    .padding(.top, VoltSpacing.lg)
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.4)

                    if mode == .signUp {
                        Text("By creating an account you agree to our Terms of Service.")
                            .font(VoltFont.mono(11)).tracking(0.3)
                            .foregroundStyle(VoltColor.labelTertiary)
                            .padding(.top, VoltSpacing.md)
                    }

                    // Divider
                    HStack(spacing: VoltSpacing.md) {
                        VoltRule()
                        Text("OR").font(VoltFont.mono(11)).tracking(0.9).foregroundStyle(VoltColor.labelTertiary)
                        VoltRule()
                    }
                    .padding(.vertical, VoltSpacing.lg)

                    // Sign in with Apple (square, like every other control)
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        let nonce = randomNonce()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256Nonce(nonce)
                    }, onCompletion: { result in
                        Task { await handleAppleSignIn(result) }
                    })
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 56)
                    .disabled(isSocialLoading)
                    .opacity(isSocialLoading ? 0.6 : 1)

                    VoltButton("Sign in with Google", style: .secondary, isLoading: isSocialLoading) {
                        Task { await handleGoogleSignIn() }
                    }
                    .padding(.top, VoltSpacing.sm)
                    .disabled(isSocialLoading)

                    // No account: keep everything on this phone. Cloud backup can be added later from Profile.
                    Button { localMode = true } label: {
                        Text("CONTINUE WITHOUT AN ACCOUNT")
                            .font(VoltFont.mono(11, weight: .medium)).tracking(0.9)
                            .underline(true, color: VoltColor.label)
                            .foregroundStyle(VoltColor.label)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, VoltSpacing.sm)

                    Spacer(minLength: VoltSpacing.xxl)
                }
                .padding(.horizontal, VoltSpacing.gutter)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: - Subviews

    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false,
        contentType: UITextContentType? = nil
    ) -> some View {
        let focused = focusedField == field
        let prompt = Text(placeholder).foregroundStyle(VoltColor.labelTertiary)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(VoltFont.mono(11)).tracking(0.8)
                .foregroundStyle(focused ? VoltColor.label : VoltColor.labelSecondary)

            Group {
                if isSecure {
                    SecureField("", text: text, prompt: prompt)
                        .textContentType(contentType)
                } else {
                    TextField("", text: text, prompt: prompt)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(contentType)
                }
            }
            .focused($focusedField, equals: field)
            .font(VoltFont.sans(17))
            .foregroundStyle(VoltColor.label)
            .frame(height: 44)
            .accessibilityLabel(label)

            Rectangle()
                .fill(focused ? VoltColor.accent : VoltColor.label)
                .frame(height: focused ? 2 : 1)
        }
        .animation(.easeInOut(duration: 0.15), value: focused)
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passOK  = password.count >= 6
        if mode == .signUp { return emailOK && passOK && confirmPassword == password }
        return emailOK && passOK
    }

    // MARK: - Social Sign In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isSocialLoading = true
        errorMessage = nil
        defer { isSocialLoading = false }
        switch result {
        case .failure(let error):
            // User cancelled — ASAuthorizationError.canceled — don't show error
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple Sign In failed — missing credentials"
                return
            }
            do {
                try await supabase.signInWithApple(idToken: idToken, rawNonce: nonce)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func handleGoogleSignIn() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else { return }
        isSocialLoading = true
        errorMessage = nil
        defer { isSocialLoading = false }
        do {
            try await supabase.signInWithGoogle(presenting: window)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Submit

    private func submit() async {
        focusedField = nil
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if mode == .signIn {
                try await supabase.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            } else {
                guard password == confirmPassword else {
                    errorMessage = "Passwords don't match"
                    return
                }
                try await supabase.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environment(SupabaseManager.shared)
}
