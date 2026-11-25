import Foundation
import CoreText

@main struct LyricsFontChecks {
    static func main() {
        for name in ["Fraunces72pt-Bold", "Literata72pt-ExtraBold"] {
            let url = URL(fileURLWithPath: "Metal/Fonts/\(name).ttf")
            var error: Unmanaged<CFError>?
            precondition(CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error), "Font could not be registered: \(name)")
            let font = CTFontCreateWithName(name as CFString, 29, nil)
            precondition(CTFontCopyPostScriptName(font) as String == name, "Incorrect PostScript name")
            var characters = Array((name == "Literata72pt-ExtraBold" ?
                "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюяЇїІіЄєҐґEnglish" : "English lyrics").utf16)
            let count = characters.count
            var glyphs = [CGGlyph](repeating: 0, count: count)
            precondition(CTFontGetGlyphsForCharacters(font, &characters, &glyphs, count))
            precondition(glyphs.allSatisfy { $0 != 0 }, "Missing lyrics glyphs")
        }
        print("Lyrics PostScript names, font registration, Latin and complete Russian/Ukrainian glyph coverage passed")
    }
}
