import Testing
@testable import IndouKit

@Suite("GridNavigator")
struct GridNavigatorTests {
    @Test("Tab 은 순환 next")
    func tabWraps() {
        #expect(GridNavigator.next(from: 0, count: 4) == 1)
        #expect(GridNavigator.next(from: 3, count: 4) == 0)
    }

    @Test("Shift+Tab 은 순환 previous")
    func shiftTabWraps() {
        #expect(GridNavigator.previous(from: 0, count: 4) == 3)
        #expect(GridNavigator.previous(from: 2, count: 4) == 1)
    }

    @Test("화살표 2D 이동 (4열 그리드)")
    func arrows2D() {
        // 0 1 2 3
        // 4 5 6 7
        #expect(GridNavigator.move(from: 0, .right, columns: 4, count: 8) == 1)
        #expect(GridNavigator.move(from: 0, .down, columns: 4, count: 8) == 4)
        #expect(GridNavigator.move(from: 5, .up, columns: 4, count: 8) == 1)
        #expect(GridNavigator.move(from: 5, .left, columns: 4, count: 8) == 4)
    }

    @Test("화살표는 모서리에서 클램프")
    func arrowsClamp() {
        #expect(GridNavigator.move(from: 0, .left, columns: 4, count: 8) == 0)
        #expect(GridNavigator.move(from: 0, .up, columns: 4, count: 8) == 0)
        #expect(GridNavigator.move(from: 3, .right, columns: 4, count: 8) == 3)
    }

    @Test("마지막 부분 행의 빈 칸으로 가지 않음")
    func partialLastRow() {
        // count=6, 4열: 행0=[0..3], 행1=[4,5]
        #expect(GridNavigator.move(from: 2, .down, columns: 4, count: 6) == 2)
        #expect(GridNavigator.move(from: 1, .down, columns: 4, count: 6) == 5)
    }
}

@Suite("SelectionState")
struct SelectionStateTests {
    private let windows = [WindowState(id: 10), WindowState(id: 20), WindowState(id: 30)]

    @Test("다중 선택 토글")
    func toggle() {
        var s = SelectionState()
        s.toggleMultiSelection(10)
        s.toggleMultiSelection(20)
        #expect(s.isMultiSelected(10))
        s.toggleMultiSelection(10)
        #expect(!s.isMultiSelected(10))
        #expect(s.hasMultiSelection)
    }

    @Test("actionTargets: 다중 선택 우선")
    func targetsMulti() {
        var s = SelectionState(focusedIndex: 0)
        s.setMultiSelection([20, 30])
        #expect(s.actionTargets(in: windows) == [20, 30])
    }

    @Test("actionTargets: 선택 없으면 포커스 윈도우")
    func targetsFocus() {
        let s = SelectionState(focusedIndex: 1)
        #expect(s.actionTargets(in: windows) == [20])
    }
}
