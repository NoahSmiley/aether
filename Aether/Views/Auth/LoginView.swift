import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var contentOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var formOffset: CGFloat = 30
    @FocusState private var focusedField: LoginField?
    @FocusState private var isSignInFocused: Bool
    @FocusState private var isChangeServerFocused: Bool

    private let accentViolet = Color(red: 0.424, green: 0.361, blue: 0.906)

    private enum LoginField: Hashable {
        case username, password
    }

    var body: some View {
        ZStack {
            // Deep cinematic background
            Color.black.ignoresSafeArea()

            // Subtle radial glow centered on the form
            RadialGradient(
                colors: [
                    accentViolet.opacity(0.06),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()

            // Vignette overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.5),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Server info header
                if let info = viewModel.serverInfo {
                    HStack(spacing: AetherTheme.spacingSM) {
                        Circle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: 8, height: 8)

                        Text(info.serverName)
                            .font(.system(size: AetherTheme.captionSize, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .offset(y: headerOffset)
                    .padding(.bottom, AetherTheme.spacingLG)
                }

                // Logo + Title
                Image("LogoWhite")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .padding(.bottom, AetherTheme.spacingMD)

                Text("Sign In")
                    .font(.system(size: AetherTheme.titleSize, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(1)
                    .padding(.bottom, AetherTheme.spacingXXL)

                // Login form
                VStack(spacing: AetherTheme.spacingLG) {
                    // Username
                    VStack(alignment: .leading, spacing: AetherTheme.spacingSM) {
                        if focusedField == .username || !viewModel.username.isEmpty {
                            Text("Username")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(
                                    focusedField == .username
                                        ? accentViolet
                                        : Color.white.opacity(0.4)
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        TextField("Username", text: $viewModel.username)
                            .textFieldStyle(.plain)
                            .font(.system(size: AetherTheme.bodySize, weight: .regular))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AetherTheme.spacingLG)
                            .padding(.vertical, 22)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(focusedField == .username ? 0.12 : 0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                focusedField == .username
                                                    ? accentViolet.opacity(0.6)
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            )
                            .shadow(
                                color: focusedField == .username ? accentViolet.opacity(0.25) : Color.clear,
                                radius: 20, x: 0, y: 4
                            )
                            .focused($focusedField, equals: .username)
                            .animation(.easeInOut(duration: 0.25), value: focusedField)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: AetherTheme.spacingSM) {
                        if focusedField == .password || !viewModel.password.isEmpty {
                            Text("Password")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(
                                    focusedField == .password
                                        ? accentViolet
                                        : Color.white.opacity(0.4)
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(.plain)
                            .font(.system(size: AetherTheme.bodySize, weight: .regular))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AetherTheme.spacingLG)
                            .padding(.vertical, 22)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(focusedField == .password ? 0.12 : 0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                focusedField == .password
                                                    ? accentViolet.opacity(0.6)
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            )
                            .shadow(
                                color: focusedField == .password ? accentViolet.opacity(0.25) : Color.clear,
                                radius: 20, x: 0, y: 4
                            )
                            .focused($focusedField, equals: .password)
                            .animation(.easeInOut(duration: 0.25), value: focusedField)
                    }

                    // Error display
                    if let error = viewModel.error {
                        HStack(spacing: AetherTheme.spacingSM) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 18))
                            Text(error)
                                .multilineTextAlignment(.center)
                        }
                        .font(.system(size: AetherTheme.captionSize, weight: .regular))
                        .foregroundStyle(Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.85))
                        .padding(.vertical, AetherTheme.spacingSM)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Sign In button
                    Button {
                        Task { await viewModel.login() }
                    } label: {
                        HStack(spacing: AetherTheme.spacingSM) {
                            if viewModel.isLoggingIn {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            }
                            Text("Sign In")
                                .font(.system(size: AetherTheme.bodySize, weight: .bold))
                                .tracking(1)
                        }
                        .frame(maxWidth: 320)
                        .padding(.vertical, 20)
                        .background(
                            Capsule()
                                .fill(
                                    isSignInFocused
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [accentViolet, accentViolet.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                          ))
                                        : AnyShapeStyle(accentViolet)
                                )
                                .shadow(
                                    color: isSignInFocused ? accentViolet.opacity(0.6) : Color.clear,
                                    radius: isSignInFocused ? 25 : 0,
                                    x: 0, y: 8
                                )
                        )
                        .foregroundStyle(.white)
                        .scaleEffect(isSignInFocused ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isSignInFocused)
                    }
                    .buttonStyle(.plain)
                    .focused($isSignInFocused)
                    .disabled(viewModel.isLoggingIn || viewModel.username.isEmpty || viewModel.password.isEmpty)
                    .opacity((viewModel.username.isEmpty || viewModel.password.isEmpty) ? 0.5 : 1.0)
                    .padding(.top, AetherTheme.spacingSM)
                }
                .frame(maxWidth: 550)
                .offset(y: formOffset)

                Spacer()
                    .frame(height: AetherTheme.spacingXXL)

                // Change Server
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.isConnected = false
                        viewModel.serverInfo = nil
                        viewModel.error = nil
                        viewModel.username = ""
                        viewModel.password = ""
                    }
                } label: {
                    HStack(spacing: AetherTheme.spacingSM) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                        Text("Change Server")
                            .font(.system(size: AetherTheme.captionSize, weight: .regular))
                    }
                    .foregroundStyle(
                        isChangeServerFocused
                            ? Color.white.opacity(0.8)
                            : Color.white.opacity(0.3)
                    )
                    .scaleEffect(isChangeServerFocused ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isChangeServerFocused)
                }
                .buttonStyle(.plain)
                .focused($isChangeServerFocused)

                Spacer()
            }
            .padding(.horizontal, AetherTheme.spacingHuge)
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                contentOpacity = 1
                headerOffset = 0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                formOffset = 0
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.error)
    }
}
