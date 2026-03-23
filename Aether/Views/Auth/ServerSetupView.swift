import SwiftUI

struct ServerSetupView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showSuccess = false
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var formOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkRotation: Double = -90
    @State private var glowPulse = false
    @FocusState private var isURLFieldFocused: Bool
    @FocusState private var isConnectFocused: Bool

    private let accentViolet = Color(red: 0.424, green: 0.361, blue: 0.906)

    var body: some View {
        ZStack {
            // Deep cinematic background with layered gradients
            Color.black.ignoresSafeArea()

            // Subtle radial glow behind the form area
            RadialGradient(
                colors: [
                    accentViolet.opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 700
            )
            .ignoresSafeArea()

            // Top-down vignette for depth
            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: AetherTheme.spacingLG) {
                    Image("LogoWhite")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .shadow(color: accentViolet.opacity(0.4), radius: glowPulse ? 30 : 15, x: 0, y: 0)
                        .opacity(titleOpacity)

                    Text("AETHER")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .tracking(14)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(titleOpacity)

                    Text("Stream your media library")
                        .font(.system(size: AetherTheme.bodySize, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .tracking(2)
                        .opacity(subtitleOpacity)
                }
                .padding(.bottom, AetherTheme.spacingXXL)

                // Connection form
                VStack(spacing: AetherTheme.spacingLG) {
                    // Server URL field
                    TextField("https://your-server.com", text: $viewModel.serverURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: AetherTheme.bodySize, weight: .regular))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AetherTheme.spacingLG)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(isURLFieldFocused ? 0.12 : 0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            isURLFieldFocused ? accentViolet.opacity(0.6) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        )
                        .shadow(
                            color: isURLFieldFocused ? accentViolet.opacity(0.3) : Color.clear,
                            radius: 20, x: 0, y: 4
                        )
                        .focused($isURLFieldFocused)
                        .frame(maxWidth: 650)
                        .animation(.easeInOut(duration: 0.25), value: isURLFieldFocused)
                        #if DEBUG
                        .onAppear {
                            if viewModel.serverURL.isEmpty {
                                viewModel.serverURL = "http://192.168.0.159:8096"
                            }
                        }
                        #endif

                    // Connect button
                    Button {
                        Task { await viewModel.connectToServer() }
                    } label: {
                        HStack(spacing: AetherTheme.spacingSM) {
                            if viewModel.isConnecting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            }
                            Text("Connect")
                                .font(.system(size: AetherTheme.bodySize, weight: .bold))
                                .tracking(1)
                        }
                        .frame(maxWidth: 320)
                        .padding(.vertical, 20)
                        .background(
                            Capsule()
                                .fill(
                                    isConnectFocused
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [accentViolet, accentViolet.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                          ))
                                        : AnyShapeStyle(accentViolet)
                                )
                                .shadow(
                                    color: isConnectFocused ? accentViolet.opacity(0.6) : Color.clear,
                                    radius: isConnectFocused ? 25 : 0,
                                    x: 0, y: 8
                                )
                        )
                        .foregroundStyle(.white)
                        .scaleEffect(isConnectFocused ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isConnectFocused)
                    }
                    .buttonStyle(.plain)
                    .focused($isConnectFocused)
                    .disabled(viewModel.isConnecting || viewModel.serverURL.isEmpty)
                    .opacity(viewModel.serverURL.isEmpty ? 0.5 : 1.0)
                }
                .opacity(formOpacity)

                // Status area
                VStack(spacing: AetherTheme.spacingSM) {
                    if viewModel.isConnecting {
                        HStack(spacing: AetherTheme.spacingSM) {
                            ProgressView()
                                .tint(Color.white.opacity(0.6))
                                .scaleEffect(0.8)
                            Text("Connecting...")
                                .font(.system(size: AetherTheme.captionSize, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if showSuccess, let info = viewModel.serverInfo {
                        HStack(spacing: AetherTheme.spacingMD) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.green)
                                    .scaleEffect(checkmarkScale)
                                    .rotationEffect(.degrees(checkmarkRotation))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(info.serverName)
                                    .font(.system(size: AetherTheme.bodySize, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("v\(info.version)")
                                    .font(.system(size: AetherTheme.captionSize, weight: .light))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else if let error = viewModel.error {
                        HStack(spacing: AetherTheme.spacingSM) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.8))

                            Text(error)
                                .font(.system(size: AetherTheme.captionSize, weight: .regular))
                                .foregroundStyle(Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(height: 60)
                .padding(.top, AetherTheme.spacingXL)
                .animation(.easeInOut(duration: 0.35), value: viewModel.isConnecting)
                .animation(.easeInOut(duration: 0.35), value: viewModel.error)

                Spacer()
            }
            .padding(.horizontal, AetherTheme.spacingHuge)
        }
        .onAppear {
            // Staggered entrance animation
            withAnimation(.easeOut(duration: 0.8)) {
                titleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                subtitleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                formOpacity = 1
            }
            // Subtle glow pulse
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(1)) {
                glowPulse = true
            }
        }
        .onChange(of: viewModel.isConnected) { _, isConnected in
            if isConnected {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showSuccess = true
                    checkmarkScale = 1.0
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    checkmarkRotation = 0
                }
            }
        }
    }
}
