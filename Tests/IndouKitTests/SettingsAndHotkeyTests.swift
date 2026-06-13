import Foundation
import Testing
@testable import IndouKit

@Suite("SettingsSchema 마이그레이션/코덱")
struct SettingsSchemaTests {
    @Test("라운드트립: 인코드→디코드 동일")
    func roundTrip() throws {
        var s = SettingsSchema()
        s.appearance.style = .titles
        s.animation.enabled = false
        let data = try SettingsCodec.encode(s)
        let back = try SettingsCodec.decode(data)
        #expect(back == s)
    }

    @Test("부분 JSON 디코드: 누락 키는 기본값 유지")
    func partialDecodeKeepsDefaults() throws {
        // animation.enabled 만 담긴 JSON → 나머지 필드는 기본값
        let json = #"{"version":1,"animation":{"enabled":false}}"#.data(using: .utf8)!
        let s = try SettingsCodec.decode(json)
        #expect(s.animation.enabled == false)
        #expect(s.animation.durationMs == AnimationSettings().durationMs)
        #expect(s.appearance.style == AppearanceSettings().style)
        // profiles 누락 → 기본 프로필로 채움
        #expect(s.profiles.count == ShortcutProfile.defaults.count)
    }

    @Test("빈 JSON 객체도 전체 기본값")
    func emptyObject() throws {
        let s = try SettingsCodec.decode("{}".data(using: .utf8)!)
        #expect(s == SettingsSchema())
    }

    @Test("profiles 빈 배열이면 기본 프로필 복구")
    func emptyProfilesRestored() throws {
        let json = #"{"profiles":[]}"#.data(using: .utf8)!
        let s = try SettingsCodec.decode(json)
        #expect(!s.profiles.isEmpty)
    }
}

@Suite("ShortcutMatcher")
struct ShortcutMatcherTests {
    private let allWindows = ShortcutProfile(name: "All", holdModifiers: .option, nextKey: KeyCode.tab)

    @Test("⌥+Tab 트리거 매칭")
    func optionTabTriggers() {
        #expect(ShortcutMatcher.isTrigger(allWindows, modifiers: .option, keyCode: KeyCode.tab))
    }

    @Test("⌥⇧+Tab 도 트리거(역방향 허용)")
    func optionShiftTabTriggers() {
        #expect(ShortcutMatcher.isTrigger(allWindows, modifiers: [.option, .shift], keyCode: KeyCode.tab))
        #expect(ShortcutMatcher.isReverse(allWindows, modifiers: [.option, .shift]))
    }

    @Test("⌥⌘+Tab 은 트리거 아님(허용 외 모디파이어)")
    func optionCommandTabRejected() {
        #expect(!ShortcutMatcher.isTrigger(allWindows, modifiers: [.option, .command], keyCode: KeyCode.tab))
    }

    @Test("다른 키는 트리거 아님")
    func wrongKey() {
        #expect(!ShortcutMatcher.isTrigger(allWindows, modifiers: .option, keyCode: KeyCode.space))
    }

    @Test("hold 모디파이어를 떼면 holdReleased")
    func holdRelease() {
        #expect(!ShortcutMatcher.holdReleased(allWindows, currentModifiers: .option))
        #expect(ShortcutMatcher.holdReleased(allWindows, currentModifiers: []))
    }

    @Test("firstMatch: 프로필 목록에서 첫 매칭")
    func firstMatch() {
        let p = ShortcutProfile.defaults
        let m = ShortcutMatcher.firstMatch(in: p, modifiers: .option, keyCode: KeyCode.backtick)
        #expect(m?.filter.appsToShow == .active)
    }
}
