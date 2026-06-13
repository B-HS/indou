import Foundation

/// A window that matched a search query, with per-field highlight indices.
public struct WindowSearchHit: Sendable, Equatable {
    public let window: WindowState
    public let score: Int
    public let titleMatches: [Int]
    public let appMatches: [Int]
}

/// Ranks windows against a query by searching both the window title and the app
/// name with the Latin (`FuzzyMatcher`) and Korean (`HangulMatcher`) matchers,
/// keeping the better of the two per field. Pure and testable.
public enum WindowSearch {
    /// Best of Latin fuzzy and Hangul initials matching for one string.
    public static func bestMatch(query: String, in text: String) -> MatchResult? {
        let fuzzy = FuzzyMatcher.match(query: query, candidate: text)
        let hangul = HangulMatcher.match(query: query, candidate: text)
        switch (fuzzy, hangul) {
        case let (f?, h?): return f.score >= h.score ? f : h
        case let (f?, nil): return f
        case let (nil, h?): return h
        case (nil, nil): return nil
        }
    }

    public static func search(query: String, windows: [WindowState]) -> [WindowSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return windows.map { WindowSearchHit(window: $0, score: 0, titleMatches: [], appMatches: []) }
        }

        var hits: [WindowSearchHit] = []
        for window in windows {
            let titleResult = bestMatch(query: trimmed, in: window.title)
            let appResult = bestMatch(query: trimmed, in: window.appName)
            // Title matches rank a touch higher than app-name matches on ties.
            let titleScore = titleResult.map { $0.score + 1 } ?? Int.min
            let appScore = appResult?.score ?? Int.min
            guard titleScore != Int.min || appScore != Int.min else { continue }

            hits.append(WindowSearchHit(
                window: window,
                score: max(titleScore, appScore),
                titleMatches: titleResult?.matchedIndices ?? [],
                appMatches: appResult?.matchedIndices ?? []
            ))
        }

        return hits.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.window.lastFocusOrder > $1.window.lastFocusOrder
        }
    }
}
