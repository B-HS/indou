import Testing
@testable import IndouKit

@Suite("ChromiumCompatibility")
struct ChromiumCompatibilityTests {
    @Test("Chrome과 Codex는 보수적 창 처리를 사용한다")
    func affectedApps() {
        #expect(ChromiumCompatibility.requiresConservativeWindowHandling("com.google.Chrome"))
        #expect(ChromiumCompatibility.requiresConservativeWindowHandling("com.openai.codex"))
    }

    @Test("다른 앱과 nil은 기존 창 처리를 유지한다")
    func unaffectedApps() {
        #expect(!ChromiumCompatibility.requiresConservativeWindowHandling("com.apple.Safari"))
        #expect(!ChromiumCompatibility.requiresConservativeWindowHandling(nil))
    }
}
