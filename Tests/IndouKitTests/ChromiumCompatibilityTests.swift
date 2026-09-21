import Testing
@testable import IndouKit

@Suite("ChromiumCompatibility")
struct ChromiumCompatibilityTests {
    @Test("Chrome과 Codex는 공개 창 포커스를 사용한다")
    func affectedApps() {
        #expect(ChromiumCompatibility.requiresPublicWindowFocus("com.google.Chrome"))
        #expect(ChromiumCompatibility.requiresPublicWindowFocus("com.openai.codex"))
    }

    @Test("다른 앱과 nil은 기존 창 처리를 유지한다")
    func unaffectedApps() {
        #expect(!ChromiumCompatibility.requiresPublicWindowFocus("com.apple.Safari"))
        #expect(!ChromiumCompatibility.requiresPublicWindowFocus(nil))
    }
}
