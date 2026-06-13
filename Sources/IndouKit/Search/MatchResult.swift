import Foundation

/// The outcome of matching a query against a candidate string. `score` is
/// comparable across tiers (higher = better); `matchedIndices` are offsets into
/// the original candidate's `Character` array, used to bold the matched glyphs.
public struct MatchResult: Sendable, Equatable {
    public let score: Int
    public let matchedIndices: [Int]

    public init(score: Int, matchedIndices: [Int]) {
        self.score = score
        self.matchedIndices = matchedIndices
    }
}

/// Tier base scores. Spacing leaves room for per-tier tie-breaker adjustments.
enum MatchTier: Int {
    case exact = 6000
    case textPrefix = 5000
    case wordPrefix = 4000
    case substring = 3000
    case acronym = 2000
    case fuzzy = 1000
}

enum TextNormalize {
    /// Fold one character to a single lowercased, diacritic-insensitive character,
    /// preserving 1:1 index alignment with the original (good enough for window
    /// titles; multi-scalar folds like ß→ss collapse to their first scalar).
    static func fold(_ ch: Character) -> Character {
        let folded = String(ch).folding(options: .diacriticInsensitive, locale: nil).lowercased()
        return folded.first ?? ch
    }

    static func isSeparator(_ ch: Character) -> Bool {
        if ch.isWhitespace { return true }
        return "_-./:\\|,()[]{}".contains(ch)
    }

    /// Word-start flags computed from the ORIGINAL characters so camelCase and
    /// letter↔digit transitions survive (lowercasing would erase them).
    static func wordStarts(_ original: [Character]) -> [Bool] {
        var flags = [Bool](repeating: false, count: original.count)
        for i in original.indices {
            if i == 0 {
                flags[i] = !isSeparator(original[i])
                continue
            }
            let prev = original[i - 1]
            let cur = original[i]
            if isSeparator(prev), !isSeparator(cur) {
                flags[i] = true
            } else if prev.isLowercase, cur.isUppercase {
                flags[i] = true
            } else if prev.isNumber != cur.isNumber, !isSeparator(cur) {
                flags[i] = true
            }
        }
        return flags
    }
}
