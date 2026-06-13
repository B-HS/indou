import Foundation

/// Korean initial-consonant (초성) search: typing "ㅂㄹㅇ" matches "브라우저".
/// Decomposes each Hangul syllable to its leading jamo and matches the query as
/// a prefix (strong) or in-order subsequence (weaker) of that initials string.
public enum HangulMatcher {
    private static let leads: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]
    private static let leadSet = Set("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")

    /// True when the string contains a standalone Hangul consonant jamo (what a
    /// Korean keyboard emits when you type consonants only).
    public static func containsLeadJamo(_ s: String) -> Bool {
        s.contains { leadSet.contains($0) }
    }

    private static func leadJamo(of ch: Character) -> Character? {
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return nil }
        let v = scalar.value
        guard (0xAC00 ... 0xD7A3).contains(v) else { return nil }
        let index = Int(v - 0xAC00) / 588
        return leads[index]
    }

    /// Per-character initials string, index-aligned to the original characters.
    /// Hangul syllables → their lead jamo; everything else → folded lowercase.
    static func initials(_ original: [Character]) -> [Character] {
        original.map { leadJamo(of: $0) ?? TextNormalize.fold($0) }
    }

    public static func match(query rawQuery: String, candidate rawCandidate: String) -> MatchResult? {
        let q = Array(rawQuery).map(TextNormalize.fold).filter { !$0.isWhitespace }
        guard !q.isEmpty, containsLeadJamo(rawQuery) else { return nil }

        let cand = initials(Array(rawCandidate))
        guard q.count <= cand.count else { return nil }

        // Prefix on initials.
        if cand.starts(with: q) {
            return MatchResult(score: MatchTier.wordPrefix.rawValue + 100, matchedIndices: Array(0 ..< q.count))
        }
        // Word-boundary prefix on initials.
        let starts = TextNormalize.wordStarts(Array(rawCandidate))
        for s in cand.indices where starts[s] && s > 0 && s + q.count <= cand.count {
            if Array(cand[s ..< s + q.count]).elementsEqual(q) {
                return MatchResult(score: MatchTier.wordPrefix.rawValue - s, matchedIndices: Array(s ..< s + q.count))
            }
        }
        // In-order subsequence on initials.
        var qi = 0
        var matched: [Int] = []
        for i in cand.indices where qi < q.count {
            if cand[i] == q[qi] {
                matched.append(i)
                qi += 1
            }
        }
        if qi == q.count {
            return MatchResult(score: MatchTier.acronym.rawValue - (matched.first ?? 0), matchedIndices: matched)
        }
        return nil
    }
}
