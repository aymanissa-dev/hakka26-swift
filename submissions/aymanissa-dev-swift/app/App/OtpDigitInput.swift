import SwiftUI
import UIKit

struct OtpDigitInput: View {
    let digits: [String]
    let focusedIndex: Int
    let palette: OtpPalette
    let onInput: (Int, String) -> Void
    let onBackspace: (Int) -> Void
    let onFocus: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<OtpState.length, id: \.self) { index in
                OtpDigitBox(
                    index: index,
                    digit: digits[index],
                    isFocused: focusedIndex == index,
                    palette: palette,
                    onInput: { onInput(index, $0) },
                    onBackspace: { onBackspace(index) },
                    onFocus: { onFocus(index) }
                )
                if index < OtpState.length - 1 {
                    Spacer(minLength: 8)
                }
            }
        }
    }
}

enum OtpDigitText {
    /// Keeps an empty box non-empty so UIKit still delivers backspace.
    static let emptyMarker = "\u{200B}"

    static func display(_ digit: String) -> String {
        digit.isEmpty ? emptyMarker : digit
    }

    static func cleaned(_ raw: String) -> String {
        raw.replacingOccurrences(of: emptyMarker, with: "")
    }
}

struct OtpDigitBox: View {
    let index: Int
    let digit: String
    let isFocused: Bool
    let palette: OtpPalette
    let onInput: (String) -> Void
    let onBackspace: () -> Void
    let onFocus: () -> Void

    private var showsFilled: Bool {
        !digit.isEmpty && !isFocused
    }

    private var fill: Color {
        if showsFilled { return palette.digitFilledBackground }
        if isFocused { return palette.digitFocusedBackground }
        return palette.digitEmptyBackground
    }

    private var stroke: Color {
        if showsFilled { return .clear }
        if isFocused { return palette.digitFocusedOutline }
        return palette.digitEmptyOutline
    }

    private var strokeWidth: CGFloat {
        if showsFilled { return 0 }
        return isFocused ? 1.6 : 1
    }

    private var digitColor: Color {
        showsFilled ? palette.digitFilledText : palette.textPrimary
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(stroke, lineWidth: strokeWidth))
            if digit.isEmpty {
                Text(OtpCopy.placeholder)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(palette.digitPlaceholder)
                    .accessibilityHidden(true)
            }
            OtpDigitField(
                text: digit,
                textColor: UIColor(digitColor),
                isFocused: isFocused,
                accessibilityLabel: OtpCopy.digitLabel(index + 1),
                accessibilityIdentifier: OtpID.digits[index],
                onInput: onInput,
                onBackspace: onBackspace,
                onFocus: onFocus
            )
        }
        .frame(width: 48, height: 48)
        .accessibilityElement(children: .contain)
    }
}

struct OtpDigitField: UIViewRepresentable {
    var text: String
    var textColor: UIColor
    var isFocused: Bool
    var accessibilityLabel: String
    var accessibilityIdentifier: String
    var onInput: (String) -> Void
    var onBackspace: () -> Void
    var onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> OtpBackspaceField {
        let field = OtpBackspaceField()
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.textAlignment = .center
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.smartInsertDeleteType = .no
        field.borderStyle = .none
        field.isOpaque = false
        field.backgroundColor = .clear
        field.tintColor = .clear
        field.font = .systemFont(ofSize: 20, weight: .semibold)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let coordinator = context.coordinator
        field.onDeleteBackward = { [weak coordinator] in
            coordinator?.parent.onBackspace()
        }
        return field
    }

    func updateUIView(_ field: OtpBackspaceField, context: Context) {
        context.coordinator.parent = self
        field.accessibilityLabel = accessibilityLabel
        field.accessibilityIdentifier = accessibilityIdentifier
        field.accessibilityValue = text.isEmpty ? "" : text
        field.textColor = textColor
        field.font = .systemFont(ofSize: 20, weight: .semibold)
        let shown = OtpDigitText.display(text)
        if field.text != shown {
            field.text = shown
        }
        guard isFocused, !field.isFirstResponder else { return }
        if field.window != nil {
            field.becomeFirstResponder()
        } else {
            DispatchQueue.main.async { [weak field] in
                guard let field, context.coordinator.parent.isFocused, !field.isFirstResponder else { return }
                field.becomeFirstResponder()
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: OtpBackspaceField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 48, height: proposal.height ?? 48)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OtpDigitField

        init(_ parent: OtpDigitField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocus()
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let cleaned = OtpDigitText.cleaned(string)
            if cleaned.isEmpty {
                return false
            }
            parent.onInput(cleaned)
            return false
        }
    }
}

final class OtpBackspaceField: UITextField {
    var onDeleteBackward: (() -> Void)?

    override func deleteBackward() {
        onDeleteBackward?()
    }
}
