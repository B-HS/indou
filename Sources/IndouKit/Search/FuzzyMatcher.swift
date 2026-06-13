import Foundation

/// Six-tier ranked matcher (exact → text-prefix → word-prefix → substring →
/// acronym → Damerau-Levenshtein fuzzy), diacritic- and case-insensitive, with
/// matched-glyph indices for highlighting. Pure and OS-independent.
public enum FuzzyMatcher {
    /// Returns the best match of `query` against `candidate`, or `nil` if none.
    /// A 1–2 character query skips the typo-tolerant fuzzy tier.
    public static func match(query rawQuery: String, candidate rawCandidate: String) -> MatchResult? {
        let queryChars = Array(rawQuery)
        let candChars = Array(rawCandidate)

        let q = queryChars.map(TextNormalize.fold).filter { !$0.isWhitespace }
        guard !q.isEmpty, !candChars.isEmpty else { return nil }

        let cand = candChars.map(TextNormalize.fold)
        let starts = TextNormalize.wordStarts(candChars)

        // Tier 1 — exact (ignoring whitespace on both sides).
        let candNoSpace = zip(cand, cand.indices).filter { !$0.0.isWhitespace }
        if q.elementsEqual(candNoSpace.map(\.0)) {
            return MatchResult(score: MatchTier.exact.rawValue, matchedIndices: candNoSpace.map(\.1))
        }

        // Tier 2 — text prefix.
        if let indices = prefixMatch(q, cand, from: 0) {
            return MatchResult(score: tier(.textPrefix, candCount: cand.count, at: 0), matchedIndices: indices)
        }

        // Tier 3 — word prefix (query starts at a word boundary).
        for start in cand.indices where starts[start] && start > 0 {
            if let indices = prefixMatch(q, cand, from: start) {
                return MatchResult(score: tier(.wordPrefix, candCount: cand.count, at: start), matchedIndices: indices)
            }
        }

        // Tier 4 — contiguous substring.
        if let start = substringStart(q, cand) {
            let indices = Array(start ..< start + q.count)
            return MatchResult(score: tier(.substring, candCount: cand.count, at: start), matchedIndices: indices)
        }

        // Tier 5 — acronym (subsequence of word initials).
        if let indices = acronymMatch(q, cand, starts: starts) {
            return MatchResult(score: tier(.acronym, candCount: cand.count, at: indices.first ?? 0), matchedIndices: indices)
        }

        // Tier 6 — fuzzy (Damerau-Levenshtein), 3+ chars only.
        if q.count >= 3 {
            let distance = damerauLevenshtein(q, cand)
            let threshold = max(1, q.count / 3)
            if distance <= threshold {
                let score = MatchTier.fuzzy.rawValue - distance * 50
                return MatchResult(score: score, matchedIndices: subsequenceIndices(q, cand))
            }
            // Fuzzy against the best matching word as well (titles are long).
            if let best = bestWordFuzzy(q, cand, starts: starts), best <= threshold {
                let score = MatchTier.fuzzy.rawValue - best * 50 - 10
                return MatchResult(score: score, matchedIndices: subsequenceIndices(q, cand))
            }
        }

        return nil
    }

    // MARK: - Tier helpers

    private static func tier(_ base: MatchTier, candCount: Int, at start: Int) -> Int {
        // Earlier and shorter matches rank slightly higher within a tier.
        base.rawValue - start - max(0, candCount - 64) / 8
    }

    private static func prefixMatch(_ q: [Character], _ cand: [Character], from start: Int) -> [Int]? {
        guard start + q.count <= cand.count else { return nil }
        for k in q.indices where cand[start + k] != q[k] { return nil }
        return Array(start ..< start + q.count)
    }

    private static func substringStart(_ q: [Character], _ cand: [Character]) -> Int? {
        guard q.count <= cand.count else { return nil }
        let last = cand.count - q.count
        for start in 0 ... last {
            var ok = true
            for k in q.indices where cand[start + k] != q[k] { ok = false; break }
            if ok { return start }
        }
        return nil
    }

    private static func acronymMatch(_ q: [Character], _ cand: [Character], starts: [Bool]) -> [Int]? {
        let initials = cand.indices.filter { starts[$0] }
        var qi = 0
        var matched: [Int] = []
        for idx in initials {
            if qi < q.count, cand[idx] == q[qi] {
                matched.append(idx)
                qi += 1
                if qi == q.count { return matched }
            }
        }
        return qi == q.count ? matched : nil
    }

    /// Greedy in-order subsequence indices for highlighting fuzzy matches.
    private static func subsequenceIndices(_ q: [Character], _ cand: [Character]) -> [Int] {
        var qi = 0
        var matched: [Int] = []
        for i in cand.indices where qi < q.count {
            if cand[i] == q[qi] {
                matched.append(i)
                qi += 1
            }
        }
        return matched
    }

    private static func bestWordFuzzy(_ q: [Character], _ cand: [Character], starts: [Bool]) -> Int? {
        let starts = cand.indices.filter { starts[$0] }
        guard !starts.isEmpty else { return nil }
        var best: Int?
        for (n, s) in starts.enumerated() {
            let end = n + 1 < starts.count ? starts[n + 1] : cand.count
            let word = Array(cand[s ..< end])
            let d = damerauLevenshtein(q, word)
            best = best.map { min($0, d) } ?? d
        }
        return best
    }

    // MARK: - Damerau-Levenshtein

    static func damerauLevenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        let n = a.count, m = b.count
        var d = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in 0 ... n { d[i][0] = i }
        for j in 0 ... m { d[0][j] = j }
        for i in 1 ... n {
            for j in 1 ... m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(
                    d[i - 1][j] + 1,
                    d[i][j - 1] + 1,
                    d[i - 1][j - 1] + cost
                )
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
                }
            }
        }
        return d[n][m]
    }
}
