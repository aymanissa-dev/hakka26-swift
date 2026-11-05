import SwiftUI
import XCTest
@testable import App

final class OtpReducerTests: XCTestCase {
    func testInitialStateIsEmptyFocusedAndCounting() {
        let state = OtpState.initial
        XCTAssertEqual(state.digits, ["", "", "", "", "", ""])
        XCTAssertEqual(state.focusedIndex, 0)
        XCTAssertEqual(state.status, .idle)
        XCTAssertEqual(state.secondsRemaining, 30)
        XCTAssertFalse(state.canSubmit)
        XCTAssertFalse(state.canResend)
        XCTAssertEqual(state.statusMessage, "")
    }

    func testTypingADigitAdvancesFocus() {
        let state = OtpReducer.reduce(.initial, .input(index: 0, text: "2"))
        XCTAssertEqual(state.digits, ["2", "", "", "", "", ""])
        XCTAssertEqual(state.focusedIndex, 1)
    }

    func testTypingRejectsNonDigits() {
        let state = OtpReducer.reduce(.initial, .input(index: 0, text: "a"))
        XCTAssertEqual(state, .initial)
        let spaced = OtpReducer.reduce(.initial, .input(index: 0, text: " "))
        XCTAssertEqual(spaced, .initial)
    }

    func testTypingTheSixthDigitStaysOnTheLastBox() {
        var state = OtpState.initial
        for (index, character) in "123456".enumerated() {
            state = OtpReducer.reduce(state, .input(index: index, text: String(character)))
        }
        XCTAssertEqual(state.code, "123456")
        XCTAssertEqual(state.focusedIndex, 5)
        XCTAssertTrue(state.canSubmit)
    }

    func testZeroIsStoredAsADigitAndIsNotThePlaceholder() {
        let state = OtpReducer.reduce(.initial, .input(index: 0, text: "0"))
        XCTAssertEqual(state.digits[0], "0")
        XCTAssertNotEqual(OtpCopy.placeholder, "0")
        XCTAssertFalse(OtpCopy.placeholder.contains("0"))
    }

    func testBackspaceOnAFilledBoxClearsIt() {
        let filled = OtpReducer.reduce(.initial, .input(index: 0, text: "4"))
        let cleared = OtpReducer.reduce(filled, .backspace(index: 0))
        XCTAssertEqual(cleared.digits[0], "")
        XCTAssertEqual(cleared.focusedIndex, 0)
    }

    func testBackspaceOnAnEmptyBoxClearsThePreviousDigit() {
        var state = OtpReducer.reduce(.initial, .input(index: 0, text: "2"))
        state = OtpReducer.reduce(state, .input(index: 1, text: "1"))
        state = OtpReducer.reduce(state, .backspace(index: 2))
        XCTAssertEqual(state.digits, ["2", "", "", "", "", ""])
        XCTAssertEqual(state.focusedIndex, 1)
    }

    func testBackspaceOnTheFirstEmptyBoxDoesNothing() {
        XCTAssertEqual(OtpReducer.reduce(.initial, .backspace(index: 0)), .initial)
    }

    func testPasteSentenceFillsAllSixDigits() {
        let state = OtpReducer.reduce(.initial, .input(index: 2, text: "Your code is 482913"))
        XCTAssertEqual(state.digits, ["4", "8", "2", "9", "1", "3"])
        XCTAssertEqual(state.code, "482913")
        XCTAssertEqual(state.focusedIndex, 5)
        XCTAssertEqual(state.status, .idle)
        XCTAssertTrue(state.canSubmit)
    }

    func testPasteUsesTheFirstSixDigits() {
        let state = OtpReducer.reduce(.initial, .input(index: 0, text: "code 48291399"))
        XCTAssertEqual(state.code, "482913")
    }

    func testShortPasteFillsFromTheActiveIndex() {
        var state = OtpReducer.reduce(.initial, .input(index: 0, text: "9"))
        state = OtpReducer.reduce(state, .input(index: 3, text: "12"))
        XCTAssertEqual(state.digits, ["9", "", "", "1", "2", ""])
        XCTAssertEqual(state.focusedIndex, 5)
    }

    func testSubmitIsIgnoredUntilTheCodeIsComplete() {
        let partial = OtpReducer.reduce(.initial, .input(index: 0, text: "12345"))
        XCTAssertFalse(partial.canSubmit)
        XCTAssertEqual(OtpReducer.reduce(partial, .submit), partial)
    }

    func testAcceptedCodeShowsSuccess() {
        let ready = filled("123456")
        let submitted = OtpReducer.reduce(ready, .submit)
        XCTAssertEqual(submitted.status, .success)
        XCTAssertEqual(submitted.statusMessage, "You're in.")
        XCTAssertEqual(submitted.code, "123456")
        XCTAssertEqual(OtpCopy.success, "You're in.")
    }

    func testWrongCodeShowsErrorClearsBoxesAndFocusesTheFirst() {
        let ready = filled("482913", secondsRemaining: 12)
        let submitted = OtpReducer.reduce(ready, .submit)
        XCTAssertEqual(submitted.status, .error)
        XCTAssertEqual(submitted.statusMessage, "That code didn't work. Try again.")
        XCTAssertEqual(submitted.digits, ["", "", "", "", "", ""])
        XCTAssertEqual(submitted.focusedIndex, 0)
        XCTAssertEqual(submitted.secondsRemaining, 12)
        XCTAssertEqual(OtpCopy.failure, "That code didn't work. Try again.")
    }

    func testTypingAfterAnErrorReturnsToIdle() {
        let failed = OtpReducer.reduce(filled("000000"), .submit)
        let typed = OtpReducer.reduce(failed, .input(index: 0, text: "1"))
        XCTAssertEqual(typed.status, .idle)
        XCTAssertEqual(typed.statusMessage, "")
        XCTAssertEqual(typed.digits[0], "1")
    }

    func testTickCountsDownAndStopsAtZero() {
        var state = OtpState.initial
        state = OtpReducer.reduce(state, .tick)
        XCTAssertEqual(state.secondsRemaining, 29)
        XCTAssertEqual(OtpCopy.countdown(seconds: state.secondsRemaining), "Resend in 0:29")
        state.secondsRemaining = 1
        state = OtpReducer.reduce(state, .tick)
        XCTAssertEqual(state.secondsRemaining, 0)
        XCTAssertTrue(state.canResend)
        XCTAssertEqual(OtpReducer.reduce(state, .tick).secondsRemaining, 0)
    }

    func testResendIsIgnoredDuringTheCountdownAndRestartsAtZero() {
        let blocked = OtpReducer.reduce(.initial, .resend)
        XCTAssertEqual(blocked.secondsRemaining, 30)
        var open = OtpState.initial
        open.secondsRemaining = 0
        let restarted = OtpReducer.reduce(open, .resend)
        XCTAssertEqual(restarted.secondsRemaining, 30)
        XCTAssertFalse(restarted.canResend)
    }

    func testCountdownLabelUsesZeroMinutesAndPaddedSeconds() {
        XCTAssertEqual(OtpCopy.countdown(seconds: 30), "Resend in 0:30")
        XCTAssertEqual(OtpCopy.countdown(seconds: 5), "Resend in 0:05")
        XCTAssertEqual(OtpCopy.countdown(seconds: 0), "Resend in 0:00")
        XCTAssertTrue(OtpCopy.countdown(seconds: 9).hasPrefix("Resend in 0:"))
    }

    func testCopyMatchesTheChallengeList() {
        XCTAssertEqual(OtpCopy.title, "Enter your code")
        XCTAssertEqual(OtpCopy.subtitle, "A 6-digit code has been sent to your phone.")
        XCTAssertEqual(OtpCopy.resendIdle, "Didn't receive the code? Resend")
        XCTAssertEqual(OtpCopy.resendIdle, OtpCopy.resendPrompt + OtpCopy.resendAction)
        XCTAssertEqual(OtpCopy.submit, "Submit")
        XCTAssertEqual(OtpCopy.digitLabel(1), "Digit 1 of 6")
        XCTAssertEqual(OtpCopy.digitLabel(6), "Digit 6 of 6")
        XCTAssertEqual(OtpID.digits, [
            "otp_digit_1",
            "otp_digit_2",
            "otp_digit_3",
            "otp_digit_4",
            "otp_digit_5",
            "otp_digit_6",
        ])
        XCTAssertEqual(OtpID.submit, "otp_submit")
        XCTAssertEqual(OtpID.resend, "otp_resend")
        XCTAssertEqual(OtpID.status, "otp_status")
    }

    func testFocusIgnoresAnIndexOutsideTheBoxes() {
        XCTAssertEqual(OtpReducer.reduce(.initial, .focus(0)), .initial)
        XCTAssertEqual(OtpReducer.reduce(.initial, .focus(3)).focusedIndex, 3)
        XCTAssertEqual(OtpReducer.reduce(.initial, .focus(6)), .initial)
        XCTAssertEqual(OtpReducer.reduce(.initial, .input(index: 8, text: "1")), .initial)
    }

    func testResendLabelIsCountdownUntilZeroThenTheIdleLine() {
        XCTAssertEqual(OtpState.initial.resendLabel, "Resend in 0:30")
        XCTAssertFalse(OtpState.initial.canResend)
        var ticking = OtpState.initial
        for seconds in stride(from: 30, through: 1, by: -1) {
            ticking.secondsRemaining = seconds
            let label = ticking.resendLabel
            XCTAssertEqual(label, String(format: "Resend in 0:%02d", seconds))
            XCTAssertFalse(label.contains("Didn't receive"))
            XCTAssertFalse(ticking.canResend)
        }
        ticking.secondsRemaining = 0
        XCTAssertTrue(ticking.canResend)
        XCTAssertEqual(ticking.resendLabel, "Didn't receive the code? Resend")
        XCTAssertFalse(ticking.resendLabel.hasSuffix("."))
    }

    func testCountdownMatchesEveryRemainingSecond() {
        for seconds in 0...30 {
            XCTAssertEqual(OtpCopy.countdown(seconds: seconds), String(format: "Resend in 0:%02d", seconds))
        }
        XCTAssertEqual(OtpCopy.countdown(seconds: -3), "Resend in 0:00")
        XCTAssertEqual(OtpCopy.countdown(seconds: 90), "Resend in 0:59")
    }

    func testEmptySlotsStayBlankWhileATypedZeroIsKept() {
        let typed = OtpReducer.reduce(.initial, .input(index: 0, text: "0"))
        XCTAssertEqual(typed.digits, ["0", "", "", "", "", ""])
        XCTAssertNotEqual(typed.digits[1], "0")
        XCTAssertNotEqual(OtpCopy.placeholder, "0")
        XCTAssertFalse(OtpCopy.placeholder.contains(where: \.isNumber))
        XCTAssertEqual(OtpDigitText.display(""), OtpDigitText.emptyMarker)
        XCTAssertNotEqual(OtpDigitText.display(""), "0")
        XCTAssertNotEqual(OtpDigitText.display(""), OtpCopy.placeholder)
        XCTAssertFalse(OtpDigitText.emptyMarker.isEmpty)
        XCTAssertFalse(OtpDigitText.emptyMarker.contains(where: \.isNumber))
        XCTAssertEqual(OtpDigitText.display("0"), "0")
        XCTAssertEqual(OtpDigitText.cleaned("\u{200B}482913"), "482913")
        XCTAssertEqual(OtpDigitText.cleaned("\u{200B}"), "")
    }

    func testSubmitStaysDisabledUntilEveryBoxHasADigit() {
        var state = OtpState.initial
        XCTAssertFalse(state.canSubmit)
        for (index, character) in "12345".enumerated() {
            state = OtpReducer.reduce(state, .input(index: index, text: String(character)))
            XCTAssertFalse(state.canSubmit)
            XCTAssertEqual(OtpReducer.reduce(state, .submit), state)
        }
        state = OtpReducer.reduce(state, .input(index: 5, text: "6"))
        XCTAssertTrue(state.canSubmit)
        XCTAssertEqual(state.code, "123456")
    }

    func testAClearedBoxDisablesSubmitAgain() {
        var state = filled("123456")
        XCTAssertTrue(state.canSubmit)
        state = OtpReducer.reduce(state, .backspace(index: 3))
        XCTAssertEqual(state.digits[3], "")
        XCTAssertFalse(state.canSubmit)
        XCTAssertEqual(OtpReducer.reduce(state, .submit), state)
    }

    func testPasteSentenceFillsAllSixBoxesFromAnyIndex() {
        for index in 0..<OtpState.length {
            let state = OtpReducer.reduce(.initial, .input(index: index, text: "Your code is 482913"))
            XCTAssertEqual(state.digits, ["4", "8", "2", "9", "1", "3"])
            XCTAssertEqual(state.focusedIndex, 5)
            XCTAssertTrue(state.canSubmit)
        }
    }

    func testOnlyAsciiDigitsAreAccepted() {
        XCTAssertEqual(OtpReducer.reduce(.initial, .input(index: 0, text: "٠")), .initial)
        XCTAssertEqual(OtpReducer.reduce(.initial, .input(index: 0, text: "５")), .initial)
        XCTAssertEqual(OtpReducer.reduce(.initial, .input(index: 0, text: "no digits")), .initial)
        let mixed = OtpReducer.reduce(.initial, .input(index: 1, text: "4a8b2913"))
        XCTAssertEqual(mixed.code, "482913")
    }

    func testZeroFilledCodeIsARealAttemptAndFails() {
        let ready = filled("000000", secondsRemaining: 9)
        XCTAssertTrue(ready.canSubmit)
        XCTAssertEqual(ready.digits, Array(repeating: "0", count: 6))
        let submitted = OtpReducer.reduce(ready, .submit)
        XCTAssertEqual(submitted.statusMessage, "That code didn't work. Try again.")
        XCTAssertEqual(submitted.digits, Array(repeating: "", count: 6))
        XCTAssertEqual(submitted.focusedIndex, 0)
        XCTAssertEqual(submitted.secondsRemaining, 9)
        XCTAssertFalse(submitted.canSubmit)
    }

    func testOtherWrongCodesResetTheSameWay() {
        for code in ["123455", "654321", "111111"] {
            let submitted = OtpReducer.reduce(filled(code, secondsRemaining: 4), .submit)
            XCTAssertEqual(submitted.status, .error)
            XCTAssertEqual(submitted.statusMessage, OtpCopy.failure)
            XCTAssertEqual(submitted.digits, ["", "", "", "", "", ""])
            XCTAssertEqual(submitted.focusedIndex, 0)
            XCTAssertEqual(submitted.secondsRemaining, 4)
        }
    }

    func testBackspaceOnEmptyBoxesWalksBackToTheStart() {
        var state = OtpState.initial
        for (index, character) in "215".enumerated() {
            state = OtpReducer.reduce(state, .input(index: index, text: String(character)))
        }
        XCTAssertEqual(state.digits, ["2", "1", "5", "", "", ""])
        XCTAssertEqual(state.focusedIndex, 3)
        state = OtpReducer.reduce(state, .backspace(index: 3))
        XCTAssertEqual(state.digits, ["2", "1", "", "", "", ""])
        XCTAssertEqual(state.focusedIndex, 2)
        state = OtpReducer.reduce(state, .backspace(index: 2))
        XCTAssertEqual(state.digits, ["2", "", "", "", "", ""])
        XCTAssertEqual(state.focusedIndex, 1)
        state = OtpReducer.reduce(state, .backspace(index: 1))
        XCTAssertEqual(state.digits, ["", "", "", "", "", ""])
        XCTAssertEqual(state.focusedIndex, 0)
        XCTAssertEqual(OtpReducer.reduce(state, .backspace(index: 0)), state)
    }

    func testResendRestartsTheCountdownWithoutClearingDigits() {
        let blocked = OtpState(
            digits: ["2", "1", "5", "", "", ""],
            focusedIndex: 3,
            status: .idle,
            secondsRemaining: 12
        )
        let ignored = OtpReducer.reduce(blocked, .resend)
        XCTAssertEqual(ignored, blocked)
        var open = blocked
        open.secondsRemaining = 0
        open.status = .error
        let restarted = OtpReducer.reduce(open, .resend)
        XCTAssertEqual(restarted.secondsRemaining, 30)
        XCTAssertEqual(restarted.digits, open.digits)
        XCTAssertEqual(restarted.status, .error)
        XCTAssertEqual(restarted.resendLabel, "Resend in 0:30")
        XCTAssertFalse(restarted.canResend)
    }

    func testReplacingADigitAdvancesFromThatBox() {
        var state = OtpReducer.reduce(.initial, .input(index: 0, text: "9"))
        state = OtpReducer.reduce(state, .input(index: 0, text: "2"))
        XCTAssertEqual(state.digits[0], "2")
        XCTAssertEqual(state.focusedIndex, 1)
    }

    func testStoreAppliesDigitsAndTicksWithoutAClock() {
        let store = OtpStore(startClock: false)
        store.send(.input(index: 0, text: "0"))
        XCTAssertEqual(store.state.digits, ["0", "", "", "", "", ""])
        XCTAssertEqual(store.state.secondsRemaining, 30)
        XCTAssertEqual(store.state.resendLabel, "Resend in 0:30")
        XCTAssertFalse(store.state.canSubmit)
        store.send(.tick)
        XCTAssertEqual(store.state.secondsRemaining, 29)
        XCTAssertEqual(store.state.resendLabel, "Resend in 0:29")
        store.send(.input(index: 0, text: "a"))
        XCTAssertEqual(store.state.digits[0], "0")
    }

    func testCopyFollowsTheIssueListRatherThanTheReferenceImage() {
        XCTAssertEqual(OtpCopy.title, "Enter your code")
        XCTAssertNotEqual(OtpCopy.title, "Enter Your code")
        XCTAssertEqual(OtpCopy.subtitle, "A 6-digit code has been sent to your phone.")
        XCTAssertFalse(OtpCopy.subtitle.lowercased().contains("cell phone"))
        XCTAssertEqual(OtpCopy.resendIdle, "Didn't receive the code? Resend")
        XCTAssertFalse(OtpCopy.resendIdle.hasSuffix("Resend."))
        XCTAssertEqual(OtpCopy.success, "You're in.")
        XCTAssertEqual(OtpCopy.failure, "That code didn't work. Try again.")
        XCTAssertNotEqual(OtpCopy.placeholder, "0")
    }

    private func filled(_ code: String, secondsRemaining: Int = 30) -> OtpState {
        OtpState(
            digits: code.map { String($0) },
            focusedIndex: OtpState.length - 1,
            status: .idle,
            secondsRemaining: secondsRemaining
        )
    }
}

final class OtpPaletteTests: XCTestCase {
    func testHexParsesRGBAndLeadingAlpha() {
        let green = HexColor.parse("#12361B")
        XCTAssertEqual(green?.red ?? -1, Double(0x12) / 255, accuracy: 0.001)
        XCTAssertEqual(green?.green ?? -1, Double(0x36) / 255, accuracy: 0.001)
        XCTAssertEqual(green?.blue ?? -1, Double(0x1B) / 255, accuracy: 0.001)
        XCTAssertEqual(green?.alpha ?? -1, 1, accuracy: 0.001)

        let scrim = HexColor.parse("#99000000")
        XCTAssertEqual(scrim?.alpha ?? -1, Double(0x99) / 255, accuracy: 0.001)
        XCTAssertEqual(scrim?.red ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(scrim?.green ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(scrim?.blue ?? -1, 0, accuracy: 0.001)
        XCTAssertNil(HexColor.parse("#12"))
    }

    func testBundledColoursJSONFeedsLightAndDarkPalettes() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "colours", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(OtpColorFile.self, from: data)
        XCTAssertEqual(file.otp.light.digitFilledBackground, "#12361B")
        XCTAssertEqual(file.otp.light.digitFilledText, "#FFFFFF")
        XCTAssertEqual(file.otp.light.digitFocusedBackground, "#FFFFFF")
        XCTAssertEqual(file.otp.light.digitFocusedOutline, "#111111")
        XCTAssertEqual(file.otp.light.digitEmptyBackground, "#F1F1F1")
        XCTAssertEqual(file.otp.light.digitPlaceholder, "#9E9E9E")
        XCTAssertEqual(file.otp.light.buttonBackground, "#12361B")
        XCTAssertEqual(file.otp.light.buttonDisabledBackground, "#C9D1CB")
        XCTAssertNotEqual(file.otp.light.buttonBackground, file.otp.light.buttonDisabledBackground)
        XCTAssertNotEqual(file.otp.light.digitFilledBackground, file.otp.light.digitEmptyBackground)
        XCTAssertNotEqual(file.otp.light.digitFilledBackground, file.otp.light.digitFocusedBackground)
        XCTAssertEqual(file.otp.dark.sheet, "#161A17")
        XCTAssertEqual(file.otp.dark.digitFilledBackground, "#2E7D45")
        XCTAssertEqual(file.otp.dark.digitFilledText, "#FFFFFF")
        XCTAssertEqual(file.otp.dark.link, "#7BC795")
        XCTAssertNotEqual(file.otp.light.sheet, file.otp.dark.sheet)
        XCTAssertNotEqual(file.otp.light.textPrimary, file.otp.dark.textPrimary)
        XCTAssertNotEqual(file.otp.light.digitEmptyBackground, file.otp.dark.digitEmptyBackground)
        XCTAssertNotEqual(file.otp.light.digitFilledBackground, file.otp.dark.digitFilledBackground)

        _ = try OtpPalette.decode(data, scheme: .light)
        _ = try OtpPalette.decode(data, scheme: .dark)
    }
}
