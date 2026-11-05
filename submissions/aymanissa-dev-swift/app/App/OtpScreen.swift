import SwiftUI

struct OtpScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var store: OtpStore

    init(store: OtpStore = OtpStore()) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        let palette = OtpPalette.load(scheme: colorScheme)
        ZStack {
            palette.scrim.ignoresSafeArea()
            VStack(spacing: 0) {
                Color.clear.frame(height: 72)
                sheet(palette)
            }
        }
    }

    private func sheet(_ palette: OtpPalette) -> some View {
        VStack(spacing: 0) {
            Image("ThamaniLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 60)
                .accessibilityLabel("Thamani logo")
                .padding(.top, 28)
                .padding(.bottom, 18)

            Text(OtpCopy.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text(OtpCopy.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 26)

            OtpDigitInput(
                digits: store.state.digits,
                focusedIndex: store.state.focusedIndex,
                palette: palette,
                onInput: { index, text in store.send(.input(index: index, text: text)) },
                onBackspace: { index in store.send(.backspace(index: index)) },
                onFocus: { index in store.send(.focus(index)) }
            )

            statusLine(palette)
            resendControl(palette)
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            submitButton(palette)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(palette.sheet)
        }
        .background {
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 28,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: 28
                )
            )
            .fill(palette.sheet)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func statusLine(_ palette: OtpPalette) -> some View {
        let message = store.state.statusMessage
        return Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(store.state.status == .success ? palette.success : palette.error)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, message.isEmpty ? 0 : 14)
            .frame(height: message.isEmpty ? 0 : nil)
            .opacity(message.isEmpty ? 0 : 1)
            .accessibilityIdentifier(OtpID.status)
            .accessibilityLabel(message)
            .accessibilityHidden(message.isEmpty)
    }

    private func resendControl(_ palette: OtpPalette) -> some View {
        let counting = !store.state.canResend
        let label = store.state.resendLabel
        return Button {
            store.send(.resend)
        } label: {
            if counting {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(palette.textSecondary)
            } else {
                (
                    Text(OtpCopy.resendPrompt)
                        .font(.system(size: 15))
                        .foregroundColor(palette.textSecondary)
                    + Text(OtpCopy.resendAction)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(palette.link)
                )
            }
        }
        .buttonStyle(ResendButtonStyle())
        .disabled(counting)
        .padding(.top, 18)
        .accessibilityIdentifier(OtpID.resend)
        .accessibilityLabel(label)
    }

    private func submitButton(_ palette: OtpPalette) -> some View {
        Button {
            store.send(.submit)
        } label: {
            Text(OtpCopy.submit)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(store.state.canSubmit ? palette.buttonText : palette.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    store.state.canSubmit ? palette.buttonBackground : palette.buttonDisabledBackground,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!store.state.canSubmit)
        .accessibilityIdentifier(OtpID.submit)
    }
}

private struct ResendButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

#Preview {
    OtpScreen(store: OtpStore(startClock: false))
}
