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
        XCTAssertEqual(file.otp.light.buttonDisabledBackground, "#C9D1CB")
        XCTAssertEqual(file.otp.dark.sheet, "#161A17")
        XCTAssertEqual(file.otp.dark.digitFilledBackground, "#2E7D45")
        XCTAssertEqual(file.otp.dark.link, "#7BC795")

        _ = try OtpPalette.decode(data, scheme: .light)
        _ = try OtpPalette.decode(data, scheme: .dark)
    }
}
