import Testing
@testable import IndouKit

@Suite("FuzzyMatcher 6-tier")
struct FuzzyMatcherTests {
    @Test("정확 일치가 prefix 보다 높은 점수")
    func exactBeatsPrefix() {
        let exact = FuzzyMatcher.match(query: "Safari", candidate: "Safari")
        let prefix = FuzzyMatcher.match(query: "Saf", candidate: "Safari")
        #expect(exact != nil)
        #expect(prefix != nil)
        #expect(exact!.score > prefix!.score)
    }

    @Test("대소문자·발음구별기호 무시")
    func caseAndDiacriticInsensitive() {
        #expect(FuzzyMatcher.match(query: "cafe", candidate: "Café") != nil)
        #expect(FuzzyMatcher.match(query: "SAFARI", candidate: "safari") != nil)
    }

    @Test("word prefix: camelCase 경계에서 매칭")
    func wordPrefixCamelCase() {
        let r = FuzzyMatcher.match(query: "code", candidate: "VisualStudioCode")
        #expect(r != nil)
        // 'Code' 가 단어 경계(C 대문자)에서 시작
        #expect(r!.score > MatchTier.substring.rawValue)
    }

    @Test("acronym: 단어 첫글자")
    func acronym() {
        let r = FuzzyMatcher.match(query: "gc", candidate: "Google Chrome")
        #expect(r != nil)
        #expect(r!.matchedIndices == [0, 7])
    }

    @Test("substring 매칭")
    func substring() {
        let r = FuzzyMatcher.match(query: "tab", candidate: "AltTab")
        #expect(r != nil)
        #expect(r!.matchedIndices == [3, 4, 5])
    }

    @Test("fuzzy: 오타 1글자 허용 (3글자 이상)")
    func fuzzyTypo() {
        #expect(FuzzyMatcher.match(query: "saffari", candidate: "Safari") != nil)
        #expect(FuzzyMatcher.match(query: "chrme", candidate: "Chrome") != nil)
    }

    @Test("1~2글자 쿼리는 fuzzy 미적용")
    func shortQueryNoFuzzy() {
        // 'xz' 는 'Safari' 와 prefix/substring/acronym 어디에도 안 맞고, 2글자라 fuzzy도 스킵 → nil
        #expect(FuzzyMatcher.match(query: "xz", candidate: "Safari") == nil)
    }

    @Test("매칭 없으면 nil")
    func noMatch() {
        #expect(FuzzyMatcher.match(query: "zzzzz", candidate: "Safari") == nil)
        #expect(FuzzyMatcher.match(query: "", candidate: "Safari") == nil)
    }

    @Test("Damerau-Levenshtein 전치 거리 1")
    func transposition() {
        #expect(FuzzyMatcher.damerauLevenshtein(Array("ab"), Array("ba")) == 1)
        #expect(FuzzyMatcher.damerauLevenshtein(Array("safari"), Array("safari")) == 0)
    }
}

@Suite("HangulMatcher 초성")
struct HangulMatcherTests {
    @Test("초성 prefix: ㅂㄹㅇ → 브라우저")
    func choseongPrefix() {
        let r = HangulMatcher.match(query: "ㅂㄹㅇ", candidate: "브라우저")
        #expect(r != nil)
        #expect(r!.matchedIndices == [0, 1, 2])
    }

    @Test("초성 전체: ㅋㅋㅌ → 카카오톡")
    func choseongFull() {
        #expect(HangulMatcher.match(query: "ㅋㅋㅌ", candidate: "카카오톡") != nil)
    }

    @Test("자모 없는 쿼리는 nil (FuzzyMatcher 담당)")
    func noJamoIsNil() {
        #expect(HangulMatcher.match(query: "br", candidate: "브라우저") == nil)
    }

    @Test("매칭 안 되는 초성")
    func choseongNoMatch() {
        #expect(HangulMatcher.match(query: "ㅈㅈㅈ", candidate: "브라우저") == nil)
    }
}

@Suite("WindowSearch 랭킹")
struct WindowSearchTests {
    private func windows() -> [WindowState] {
        [
            WindowState(id: 1, title: "index.ts — Indou", appName: "Visual Studio Code", lastFocusOrder: 3),
            WindowState(id: 2, title: "Google", appName: "Safari", lastFocusOrder: 2),
            WindowState(id: 3, title: "브라우저 탭", appName: "Whale", lastFocusOrder: 1),
        ]
    }

    @Test("빈 쿼리는 전체 통과")
    func emptyPassesAll() {
        #expect(WindowSearch.search(query: "  ", windows: windows()).count == 3)
    }

    @Test("앱 이름으로 검색")
    func searchByApp() {
        let hits = WindowSearch.search(query: "safari", windows: windows())
        #expect(hits.first?.window.id == 2)
    }

    @Test("초성으로 윈도우 타이틀 검색")
    func searchByChoseong() {
        let hits = WindowSearch.search(query: "ㅂㄹㅇ", windows: windows())
        #expect(hits.first?.window.id == 3)
    }
}
