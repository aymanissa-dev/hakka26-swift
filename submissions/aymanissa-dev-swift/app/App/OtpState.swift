import Combine
import Foundation

enum OtpStatus: Equatable {
    case idle
    case success
    case error
}

enum OtpCopy {
    static let title = "Enter your code"
    static let subtitle = "A 6-digit code has been sent to your phone."
    static let resendPrompt = "Didn't receive the code? "
    static let resendAction = "Resend"
    static let resendIdle = "Didn't receive the code? Resend"
    static let submit = "Submit"
    static let success = "You're in."
    static let failure = "That code didn't work. Try again."
    static let placeholder = "–"

    static func digitLabel(_ number: Int) -> String {
        "Digit \(number) of 6"
    }

    static func countdown(seconds: Int) -> String {
        let clamped = min(max(seconds, 0), 59)
        return "Resend in 0:" + String(format: "%02d", clamped)
    }
}

enum OtpID {
    static let digits = [
        "otp_digit_1",
        "otp_digit_2",
        "otp_digit_3",
        "otp_digit_4",
        "otp_digit_5",
        "otp_digit_6",
    ]
    static let submit = "otp_submit"
    static let resend = "otp_resend"
    static let status = "otp_status"
}

struct OtpState: Equatable {
    static let length = 6
    static let resendDuration = 30
    static let acceptedCode = "123456"

    var digits: [String]
    var focusedIndex: Int
    var status: OtpStatus
    var secondsRemaining: Int

    static var initial: OtpState {
        OtpState(
            digits: Array(repeating: "", count: length),
            focusedIndex: 0,
            status: .idle,
            secondsRemaining: resendDuration
        )
    }

    var code: String { digits.joined() }

    var isComplete: Bool {
        digits.count == Self.length && digits.allSatisfy { $0.count == 1 }
    }

    var canSubmit: Bool { isComplete }
    var canResend: Bool { secondsRemaining == 0 }

    var resendLabel: String {
        canResend ? OtpCopy.resendIdle : OtpCopy.countdown(seconds: secondsRemaining)
    }

    var statusMessage: String {
        switch status {
        case .idle:
            return ""
        case .success:
            return OtpCopy.success
        case .error:
            return OtpCopy.failure
        }
    }
}

enum OtpAction: Equatable {
    case input(index: Int, text: String)
    case backspace(index: Int)
    case submit
    case tick
    case resend
    case focus(Int)
}

enum OtpReducer {
    static func reduce(_ state: OtpState, _ action: OtpAction) -> OtpState {
        switch action {
        case let .input(index, text):
            return input(state, index: index, text: text)
        case let .backspace(index):
            return backspace(state, index: index)
        case .submit:
            return submit(state)
        case .tick:
            guard state.secondsRemaining > 0 else { return state }
            var next = state
            next.secondsRemaining -= 1
            return next
        case .resend:
            guard state.canResend else { return state }
            var next = state
            next.secondsRemaining = OtpState.resendDuration
            return next
        case let .focus(index):
            guard (0..<OtpState.length).contains(index), index != state.focusedIndex else { return state }
            var next = state
            next.focusedIndex = index
            return next
        }
    }

    private static func input(_ state: OtpState, index: Int, text: String) -> OtpState {
        guard (0..<OtpState.length).contains(index) else { return state }
        if text.isEmpty {
            return backspace(state, index: index)
        }
        let digits = decimalDigits(in: text)
        guard !digits.isEmpty else { return state }
        if digits.count == 1, text.count == 1 {
            var next = state
            next.digits[index] = String(digits)
            next.focusedIndex = min(index + 1, OtpState.length - 1)
            next.status = .idle
            return next
        }
        return paste(state, digits: digits, start: index)
    }

    private static func paste(_ state: OtpState, digits: String, start: Int) -> OtpState {
        var next = state
        if digits.count >= OtpState.length {
            next.digits = digits.prefix(OtpState.length).map { String($0) }
            next.focusedIndex = OtpState.length - 1
        } else {
            var slots = state.digits
            var cursor = start
            for character in digits {
                guard cursor < OtpState.length else { break }
                slots[cursor] = String(character)
                cursor += 1
            }
            next.digits = slots
            next.focusedIndex = min(cursor, OtpState.length - 1)
        }
        next.status = .idle
        return next
    }

    private static func backspace(_ state: OtpState, index: Int) -> OtpState {
        guard (0..<OtpState.length).contains(index) else { return state }
        var next = state
        if !next.digits[index].isEmpty {
            next.digits[index] = ""
            next.focusedIndex = index
            next.status = .idle
            return next
        }
        guard index > 0 else { return state }
        next.digits[index - 1] = ""
        next.focusedIndex = index - 1
        next.status = .idle
        return next
    }

    private static func submit(_ state: OtpState) -> OtpState {
        guard state.isComplete else { return state }
        if state.code == OtpState.acceptedCode {
            var next = state
            next.status = .success
            return next
        }
        return OtpState(
            digits: Array(repeating: "", count: OtpState.length),
            focusedIndex: 0,
            status: .error,
            secondsRemaining: state.secondsRemaining
        )
    }

    private static func decimalDigits(in text: String) -> String {
        String(text.filter { character in
            guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
                return false
            }
            return scalar >= "0" && scalar <= "9"
        })
    }
}

final class OtpStore: ObservableObject {
    @Published private(set) var state: OtpState
    private var ticker: AnyCancellable?

    init(state: OtpState = .initial, startClock: Bool = true) {
        self.state = state
        guard startClock else { return }
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.send(.tick)
            }
    }

    func send(_ action: OtpAction) {
        let next = OtpReducer.reduce(state, action)
        guard next != state else { return }
        state = next
    }
}
