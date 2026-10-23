import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                VStack(spacing: 0) {
                    // Logo / brand header
                    VStack(spacing: VoltSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(VoltGradient.brand)
                                .frame(width: 80, height: 80)
                            Image(systemName: "bolt.fill")
                                .font(VoltFont.sans(36, weight: .medium))
                                .foregroundStyle(VoltColor.onInk)
                        }
                        Text("Volt")
                            .font(VoltFont.sans(34, weight: .regular))
                            .foregroundStyle(VoltColor.label)
                        Text("Performance, tracked.")
                            .font(.subheadline)
                            .foregroundStyle(VoltColor.labelSecondary)
                    }
                    .padding(.top, VoltSpacing.xxl)
                    .padding(.bottom, VoltSpacing.xl)

                    // Mode toggle
                    HStack(spacing: 0) {
                        modeTab("Sign In", selected: mode == .signIn) { withAnimation(.easeInOut(duration: 0.2)) { mode = .signIn; errorMessage = nil } }
                        modeTab("Create Account", selected: mode == .signUp) { withAnimation(.easeInOut(duration: 0.2)) { mode = .signUp; errorMessage = nil } }
                    }
                    .background(VoltColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
                    .padding(.horizontal, VoltSpacing.lg)
                    .padding(.bottom, VoltSpacing.lg)

                    // Fields
                    VStack(spacing: VoltSpacing.sm) {
                        inputField(
                            icon: "envelope",
                            placeholder: "Email address",
                            text: $email,
                            field: .email,
                            keyboard: .emailAddress,
                            contentType: .emailAddress
                        )

                        inputField(
                            icon: "lock",
                            placeholder: "Password",
                            text: $password,
                            field: .password,
                            isSecure: true,
                            contentType: mode == .signIn ? .password : .newPassword
                        )

                        if mode == .signUp {
                            inputField(
                                icon: "lock.fill",
                                placeholder: "Confirm password",
                                text: $confirmPassword,
                                field: .confirmPassword,
                                isSecure: true,
                                contentType: .newPassword
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, VoltSpacing.lg)

                    // Error
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(VoltColor.danger)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(VoltColor.danger)
                        }
                        .padding(.horizontal, VoltSpacing.lg)
                        .padding(.top, VoltSpacing.sm)
                        .transition(.opacity)
                    }

                    // CTA
                    VoltButton(
                        mode == .signIn ? "Sign In" : "Create Account",
                        icon: mode == .signIn ? "arrow.right.circle.fill" : "person.badge.plus",
                        isLoading: isLoading
                    ) {
                        Task { await submit() }
                    }
                    .padding(.horizontal, VoltSpacing.lg)
                    .padding(.top, VoltSpacing.lg)
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.5)

                    // Sign in hint
                    if mode == .signUp {
                        Text("By creating an account you agree to our Terms of Service.")
                            .font(.caption)
                            .foregroundStyle(VoltColor.labelTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, VoltSpacing.xl)
                            .padding(.top, VoltSpacing.md)
                    }

                    // Social sign-in divider
                    HStack(spacing: VoltSpacing.sm) {
                        Rectangle().frame(height: 0.5).foregroundStyle(VoltColor.border)
                        Text("or").font(.caption).foregroundStyle(VoltColor.labelTertiary)
                        Rectangle().frame(height: 0.5).foregroundStyle(VoltColor.border)
                    }
                    .padding(.horizontal, VoltSpacing.lg)
                    .padding(.top, VoltSpacing.lg)

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        let nonce = randomNonce()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256Nonce(nonce)
                    }, onCompletion: { result in
                        Task { await handleAppleSignIn(result) }
                    })
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
                    .padding(.horizontal, VoltSpacing.lg)
                    .padding(.top, VoltSpacing.sm)
                    .disabled(isSocialLoading)
                    .opacity(isSocialLoading ? 0.6 : 1)

                    // Sign in with Google
                    Button {
                        Task { await handleGoogleSignIn() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSocialLoading {
                                ProgressView().tint(VoltColor.label)
                            } else {
                                Image(systemName: "globe")
                                    .font(VoltFont.sans(18, weight: .regular))
                                    .foregroundStyle(VoltColor.label)
                                Text("Sign in with Google")
                                    .font(VoltFont.sans(16, weight: .medium))
                                    .foregroundStyle(VoltColor.label)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(VoltColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
                    }
                    .padding(.horizontal, VoltSpacing.lg)
                    .padding(.top, VoltSpacing.sm)
                    .disabled(isSocialLoading)

                    Spacer(minLength: VoltSpacing.xxl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: - Subviews

    private func modeTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? AnyShapeStyle(VoltGradient.brand) : AnyShapeStyle(Color.clear))
                .foregroundStyle(selected ? VoltColor.onInk : VoltColor.labelSecondary)
                .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius - 1))
        }
    }

    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false,
        contentType: UITextContentType? = nil
    ) -> some View {
        HStack(spacing: VoltSpacing.sm) {
            Image(systemName: icon)
                .font(VoltFont.sans(16, weight: .regular))
                .foregroundStyle(focusedField == field ? VoltColor.accent : VoltColor.labelTertiary)
                .frame(width: 22)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textContentType(contentType)
                    .focused($focusedField, equals: field)
                    .font(.subheadline)
                    .foregroundStyle(VoltColor.label)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(contentType)
                    .focused($focusedField, equals: field)
                    .font(.subheadline)
                    .foregroundStyle(VoltColor.label)
            }
        }
        .padding(VoltSpacing.md)
        .background(VoltColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
        .overlay(
            RoundedRectangle(cornerRadius: VoltSpacing.radius)
                .stroke(focusedField == field ? VoltColor.accent : VoltColor.border, lineWidth: focusedField == field ? 1 : 0.5)
        )
        .animation(.easeInOut(duration: 0.15), value: focusedField)
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
