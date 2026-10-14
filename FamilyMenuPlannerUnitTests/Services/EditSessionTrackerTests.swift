import XCTest
@testable import FamilyMenuPlanner

@MainActor
final class EditSessionTrackerTests: XCTestCase {
    func testNotifiesWhenLastEditorCloses() {
        let tracker = EditSessionTracker()
        var notifications = 0
        let token = NotificationCenter.default.addObserver(forName: .editSessionsDidEnd, object: nil, queue: nil) { _ in
            notifications += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        tracker.begin()
        tracker.begin()
        XCTAssertTrue(tracker.isEditing)

        tracker.end()
        XCTAssertTrue(tracker.isEditing)
        XCTAssertEqual(notifications, 0)

        tracker.end()
        XCTAssertFalse(tracker.isEditing)
        XCTAssertEqual(notifications, 1)

        // An unbalanced end is ignored
        tracker.end()
        XCTAssertEqual(tracker.openSessions, 0)
        XCTAssertEqual(notifications, 1)
    }
}
