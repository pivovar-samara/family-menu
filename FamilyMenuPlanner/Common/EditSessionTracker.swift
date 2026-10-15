import SwiftUI

/// Tracks open dish and product editors. An editor can save intermediate steps (e.g. ingredients) while the
/// edit is unfinished, so a clean view context alone does not mean editing is done; work that would reset the
/// view context (restarting CloudKit mirroring) waits until no editor is open.
@MainActor
final class EditSessionTracker {
    static let shared = EditSessionTracker()

    private(set) var openSessions = 0
    var isEditing: Bool { openSessions > 0 }

    func begin() {
        openSessions += 1
    }

    func end() {
        guard openSessions > 0 else { return }
        openSessions -= 1
        if openSessions == 0 {
            NotificationCenter.default.post(name: .editSessionsDidEnd, object: nil)
        }
    }
}

extension Notification.Name {
    /// Posted when the last open editor closes
    static let editSessionsDidEnd = Notification.Name("EditSessionsDidEnd")
}

private struct EditSessionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { EditSessionTracker.shared.begin() }
            .onDisappear { EditSessionTracker.shared.end() }
    }
}

extension View {
    /// Marks this view as an editor for `EditSessionTracker` while it is on screen
    func tracksEditSession() -> some View {
        modifier(EditSessionModifier())
    }
}
