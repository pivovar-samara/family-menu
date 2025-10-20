//
//  AnalyticsProvider.swift
//  FamilyMenuPlanner
//
//  Created by Ilia Khokhlov on 30.09.25.
//

import Foundation

/// A lightweight representation of an analytics event.
public struct AnalyticsEvent: Sendable {
    /// The name of the event.
    public let name: String
    /// Additional properties associated with the event.
    public let properties: [String: Sendable]

    /// Creates a new analytics event.
    /// - Parameters:
    ///   - name: The event name.
    ///   - properties: Optional additional properties.
    public init(name: String, properties: [String: Sendable] = [:]) {
        self.name = name
        self.properties = properties
    }
}

/// Represents a revenue (purchase) event.
public struct AnalyticsRevenue: Sendable {
    /// The product identifier.
    public let productId: String?
    /// The price of the product.
    public let price: Double
    /// The quantity purchased.
    public let quantity: Int
    /// The currency code (e.g. "USD").
    public let currency: String?
    /// Additional properties associated with the revenue event.
    public let properties: [String: Sendable]

    /// Creates a new revenue event.
    /// - Parameters:
    ///   - productId: Optional product identifier.
    ///   - price: Price of the product.
    ///   - quantity: Quantity purchased (default is 1).
    ///   - currency: Optional currency code.
    ///   - properties: Additional properties.
    public init(productId: String? = nil,
                price: Double,
                quantity: Int = 1,
                currency: String? = nil,
                properties: [String: Sendable] = [:]) {
        self.productId = productId
        self.price = price
        self.quantity = quantity
        self.currency = currency
        self.properties = properties
    }
}

/// Protocol that any analytics provider (Amplitude, Firebase, etc.) should conform to.
public protocol AnalyticsProvider: AnyObject {
    /// Initialize and prepare the provider with a configuration dictionary.
    /// - Parameter configuration: A free-form bag for API keys and options.
    func start(configuration: [String: Any])

    /// Identify the current user with an optional user ID and traits.
    /// - Parameters:
    ///   - userId: Optional user identifier.
    ///   - traits: User traits or attributes.
    func identify(userId: String?, traits: [String: Sendable])

    /// Track an event with optional properties.
    /// - Parameter event: The event to track.
    func track(_ event: AnalyticsEvent)

    /// Set a single user property.
    /// - Parameters:
    ///   - key: Property name.
    ///   - value: Property value, or `nil` to remove.
    func setUserProperty(_ key: String, value: Sendable?)

    /// Set multiple user properties at once.
    /// - Parameter properties: Properties to set.
    func setUserProperties(_ properties: [String: Sendable])

    /// Log a revenue (purchase) event.
    /// - Parameter revenue: The revenue event to log.
    func logRevenue(_ revenue: AnalyticsRevenue)

    /// Enable or disable tracking at runtime.
    /// - Parameter enabled: `true` to enable tracking, `false` to disable.
    func setTrackingEnabled(_ enabled: Bool)
}

/// A convenient no-op provider that does nothing. Useful for tests or when analytics is disabled.
public final class NoOpAnalyticsProvider: AnalyticsProvider {
    public init() {}
    public func start(configuration: [String : Any]) {}
    public func identify(userId: String?, traits: [String : Sendable]) {}
    public func track(_ event: AnalyticsEvent) {}
    public func setUserProperty(_ key: String, value: Sendable?) {}
    public func setUserProperties(_ properties: [String : Sendable]) {}
    public func logRevenue(_ revenue: AnalyticsRevenue) {}
    public func setTrackingEnabled(_ enabled: Bool) {}
}

/// A facade that fans out calls to one or more analytics providers.
public final class AnalyticsManager: @unchecked Sendable {
    /// The shared singleton instance.
    public static let shared = AnalyticsManager()

    private var providers: [AnalyticsProvider] = []
    private let lock = NSLock()

    /// Creates a new analytics manager instance.
    public init() {}

    /// Replace the current providers with a new list.
    /// - Parameter newProviders: The new list of analytics providers.
    public func configure(providers newProviders: [AnalyticsProvider]) {
        lock.lock(); defer { lock.unlock() }
        self.providers = newProviders
    }

    /// Start all configured providers with a configuration dictionary.
    /// - Parameter configuration: Configuration options.
    public func start(configuration: [String: Any]) {
        lock.lock(); let current = providers; lock.unlock()
        current.forEach { $0.start(configuration: configuration) }
    }

    /// Identify the current user with optional user ID and traits.
    /// - Parameters:
    ///   - userId: Optional user identifier.
    ///   - traits: Optional user traits.
    public func identify(userId: String?, traits: [String: Sendable] = [:]) {
        lock.lock(); let current = providers; lock.unlock()
        current.forEach { $0.identify(userId: userId, traits: traits) }
    }

    /// Track an event by name with optional properties.
    /// - Parameters:
    ///   - name: The event name.
    ///   - properties: Optional event properties.
    public func track(name: String, properties: [String: Sendable] = [:]) {
        track(AnalyticsEvent(name: name, properties: properties))
    }

    /// Track an event.
    /// - Parameter event: The event to track.
    public func track(_ event: AnalyticsEvent) {
        lock.lock(); let current = providers; lock.unlock()
        current.forEach { $0.track(event) }
    }

    /// Set a single user property.
    /// - Parameters:
    ///   - key: Property name.
    ///   - value: Property value, or `nil` to remove.
    public func setUserProperty(_ key: String, value: Sendable?) {
        lock.lock(); let current = providers; lock.unlock()
        current.forEach { $0.setUserProperty(key, value: value) }
    }

    /// Set multiple user properties at once.
    /// - Parameter properties: Properties to set.
    public func setUserProperties(_ properties: [String: Sendable]) {
        lock.lock(); let current = providers; lock.unlock()
        current.forEach { $0.setUserProperties(properties) }
    }

    /// Log a revenue (purchase) event.
    /// - Parameter revenue: The revenue event.
    public func logRevenue(_ revenue: AnalyticsRevenue) {
        lock.lock(); let current = providers; lock.unlock()
        current.forEach { $0.logRevenue(revenue) }
    }

    /// Enable or disable tracking at runtime.
    /// - Parameter enabled: `true` to enable tracking, `false` to disable.
    public func setTrackingEnabled(_ enabled: Bool) {
        lock.lock(); let current = providers; lock.unlock()
        current.forEach { $0.setTrackingEnabled(enabled) }
    }
}

/// Convenience helpers for common analytics patterns.
public extension AnalyticsManager {
    /// Track a screen (view) appearance event.
    /// - Parameters:
    ///   - name: Human-readable screen name. Consider using a stable value.
    ///   - properties: Additional properties to include with the event.
    func trackScreen(_ name: String, properties: [String: Sendable] = [:]) {
        var props = properties
        // Ensure the standard key is present for provider mappings.
        props[AnalyticsPropertyKey.screen_name] = name
        track(name: AnalyticsEventName.screen_view, properties: props)
    }
    
    /// Track an error event.
    /// - Parameters:
    ///   - error: An error object.
    ///   - category: Domain category for the error.
    ///   - properties: Additional properties to include.
    func trackError(_ error: Error, domain: String, category: String, properties: [String: Sendable] = [:]) {
        var props = properties
        // Ensure the standard key is present for provider mappings.
        props[AnalyticsPropertyKey.error_domain] = domain
        props[AnalyticsPropertyKey.error_category] = category
        props[AnalyticsPropertyKey.error_message] = error.localizedDescription
        track(name: AnalyticsEventName.error, properties: props)
    }
}
