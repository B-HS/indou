import Testing
@testable import IndouKit

@Suite("WindowState")
struct WindowStateTests {
    @Test("displayTitle 는 title 이 비면 appName 으로 폴백한다")
    func displayTitleFallback() {
        let withTitle = WindowState(id: 1, title: "문서.txt", appName: "TextEdit")
        #expect(withTitle.displayTitle == "문서.txt")

        let noTitle = WindowState(id: 2, title: "", appName: "Finder")
        #expect(noTitle.displayTitle == "Finder")
    }
}
