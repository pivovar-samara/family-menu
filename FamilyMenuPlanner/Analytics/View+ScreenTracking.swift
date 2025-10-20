//
//  View+ScreenTracking.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 30.09.25.
//

import SwiftUI
import Foundation

/// A modifier that sends a `screen_view` analytics event when the view appears.
public struct ScreenTrackingModifier: ViewModifier {
    private let name: String
    private let properties: [String: Sendable]

    public init(name: String, properties: [String: Sendable] = [:]) {
        self.name = name
        self.properties = properties
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                AnalyticsManager.shared.trackScreen(name, properties: properties)
            }
    }
}

public extension View {
    /// Track a screen appearance for this view.
    /// - Parameters:
    ///   - name: Optional explicit screen name. If not provided, the type name of the view is used.
    ///   - properties: Additional properties to include in the event.
    /// - Returns: A view that tracks its appearance via the shared analytics manager.
    func trackScreenAppear(name: String? = nil, properties: [String: Sendable] = [:]) -> some View {
        let resolvedName = name ?? String(describing: Self.self)
        return modifier(ScreenTrackingModifier(name: resolvedName, properties: properties))
    }

    /// Semantic alias for `trackScreenAppear`.
    func trackScreen(_ name: String, properties: [String: Sendable] = [:]) -> some View {
        modifier(ScreenTrackingModifier(name: name, properties: properties))
    }
}
