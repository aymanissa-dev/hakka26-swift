import SwiftUI

struct OtpPalette: Equatable {
    let sheet: Color
    let scrim: Color
    let textPrimary: Color
    let textSecondary: Color
    let digitFilledBackground: Color
    let digitFilledText: Color
    let digitFocusedBackground: Color
    let digitFocusedOutline: Color
    let digitEmptyBackground: Color
    let digitEmptyOutline: Color
    let digitPlaceholder: Color
    let buttonBackground: Color
    let buttonText: Color
    let buttonDisabledBackground: Color
    let link: Color
    let success: Color
    let error: Color

    private static let mainColourBytes: Data? = colourBytes(in: .main)
    private static let cachedLight = palette(from: mainColourBytes, scheme: .light)
    private static let cachedDark = palette(from: mainColourBytes, scheme: .dark)

    static func load(scheme: ColorScheme, bundle: Bundle = .main) -> OtpPalette {
        if bundle === Bundle.main {
            return scheme == .dark ? cachedDark : cachedLight
        }
        return palette(from: colourBytes(in: bundle), scheme: scheme)
    }

    private static func colourBytes(in bundle: Bundle) -> Data? {
        guard let url = bundle.url(forResource: "colours", withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static func palette(from data: Data?, scheme: ColorScheme) -> OtpPalette {
        if let data = data,
           let palette = try? decode(data, scheme: scheme) {
            return palette
        }
        return (try? decode(Data(fallbackJSON.utf8), scheme: scheme)) ?? fallback(scheme)
    }

    static func decode(_ data: Data, scheme: ColorScheme) throws -> OtpPalette {
        let file = try JSONDecoder().decode(OtpColorFile.self, from: data)
        let tokens = scheme == .dark ? file.otp.dark : file.otp.light
        return tokens.palette
    }

    private static func fallback(_ scheme: ColorScheme) -> OtpPalette {
        let dark = scheme == .dark
        func paint(_ light: String, _ night: String) -> Color {
            HexColor.color(dark ? night : light)
        }
        return OtpPalette(
            sheet: paint("#FFFFFF", "#161A17"),
            scrim: paint("#99000000", "#CC000000"),
            textPrimary: paint("#111111", "#F5F5F5"),
            textSecondary: paint("#5F6368", "#B0B5B1"),
            digitFilledBackground: paint("#12361B", "#2E7D45"),
            digitFilledText: paint("#FFFFFF", "#FFFFFF"),
            digitFocusedBackground: paint("#FFFFFF", "#161A17"),
            digitFocusedOutline: paint("#111111", "#F5F5F5"),
            digitEmptyBackground: paint("#F1F1F1", "#262B27"),
            digitEmptyOutline: paint("#E0E0E0", "#353B36"),
            digitPlaceholder: paint("#9E9E9E", "#6F7570"),
            buttonBackground: paint("#12361B", "#2E7D45"),
            buttonText: paint("#FFFFFF", "#FFFFFF"),
            buttonDisabledBackground: paint("#C9D1CB", "#2A302B"),
            link: paint("#12361B", "#7BC795"),
            success: paint("#1B7F3A", "#7BC795"),
            error: paint("#C62828", "#EF9A9A")
        )
    }

    private static let fallbackJSON = """
    {"otp":{"light":{"sheet":"#FFFFFF","scrim":"#99000000","text_primary":"#111111","text_secondary":"#5F6368","digit_filled_bg":"#12361B","digit_filled_text":"#FFFFFF","digit_focused_bg":"#FFFFFF","digit_focused_outline":"#111111","digit_empty_bg":"#F1F1F1","digit_empty_outline":"#E0E0E0","digit_placeholder":"#9E9E9E","button_bg":"#12361B","button_text":"#FFFFFF","button_disabled_bg":"#C9D1CB","link":"#12361B","success":"#1B7F3A","error":"#C62828"},"dark":{"sheet":"#161A17","scrim":"#CC000000","text_primary":"#F5F5F5","text_secondary":"#B0B5B1","digit_filled_bg":"#2E7D45","digit_filled_text":"#FFFFFF","digit_focused_bg":"#161A17","digit_focused_outline":"#F5F5F5","digit_empty_bg":"#262B27","digit_empty_outline":"#353B36","digit_placeholder":"#6F7570","button_bg":"#2E7D45","button_text":"#FFFFFF","button_disabled_bg":"#2A302B","link":"#7BC795","success":"#7BC795","error":"#EF9A9A"}}}
    """
}

struct OtpColorFile: Decodable {
    struct Themes: Decodable {
        let light: OtpColorTokens
        let dark: OtpColorTokens
    }

    let otp: Themes
}

struct OtpColorTokens: Decodable {
    let sheet: String
    let scrim: String
    let textPrimary: String
    let textSecondary: String
    let digitFilledBackground: String
    let digitFilledText: String
    let digitFocusedBackground: String
    let digitFocusedOutline: String
    let digitEmptyBackground: String
    let digitEmptyOutline: String
    let digitPlaceholder: String
    let buttonBackground: String
    let buttonText: String
    let buttonDisabledBackground: String
    let link: String
    let success: String
    let error: String

    enum CodingKeys: String, CodingKey {
        case sheet, scrim, link, success, error
        case textPrimary = "text_primary"
        case textSecondary = "text_secondary"
        case digitFilledBackground = "digit_filled_bg"
        case digitFilledText = "digit_filled_text"
        case digitFocusedBackground = "digit_focused_bg"
        case digitFocusedOutline = "digit_focused_outline"
        case digitEmptyBackground = "digit_empty_bg"
        case digitEmptyOutline = "digit_empty_outline"
        case digitPlaceholder = "digit_placeholder"
        case buttonBackground = "button_bg"
        case buttonText = "button_text"
        case buttonDisabledBackground = "button_disabled_bg"
    }

    var palette: OtpPalette {
        OtpPalette(
            sheet: HexColor.color(sheet),
            scrim: HexColor.color(scrim),
            textPrimary: HexColor.color(textPrimary),
            textSecondary: HexColor.color(textSecondary),
            digitFilledBackground: HexColor.color(digitFilledBackground),
            digitFilledText: HexColor.color(digitFilledText),
            digitFocusedBackground: HexColor.color(digitFocusedBackground),
            digitFocusedOutline: HexColor.color(digitFocusedOutline),
            digitEmptyBackground: HexColor.color(digitEmptyBackground),
            digitEmptyOutline: HexColor.color(digitEmptyOutline),
            digitPlaceholder: HexColor.color(digitPlaceholder),
            buttonBackground: HexColor.color(buttonBackground),
            buttonText: HexColor.color(buttonText),
            buttonDisabledBackground: HexColor.color(buttonDisabledBackground),
            link: HexColor.color(link),
            success: HexColor.color(success),
            error: HexColor.color(error)
        )
    }
}

enum HexColor {
    struct RGBA: Equatable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double
    }

    static func color(_ hex: String) -> Color {
        let rgba = parse(hex) ?? RGBA(red: 0, green: 0, blue: 0, alpha: 1)
        return Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    static func parse(_ hex: String) -> RGBA? {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }
        guard let value = UInt64(raw, radix: 16) else { return nil }
        switch raw.count {
        case 6:
            return RGBA(
                red: channel(value >> 16),
                green: channel(value >> 8),
                blue: channel(value),
                alpha: 1
            )
        case 8:
            return RGBA(
                red: channel(value >> 16),
                green: channel(value >> 8),
                blue: channel(value),
                alpha: channel(value >> 24)
            )
        default:
            return nil
        }
    }

    private static func channel(_ value: UInt64) -> Double {
        Double(value & 0xFF) / 255
    }
}
