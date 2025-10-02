//
//  AmplitudeAnalyticsProvider.swift
//  FamilyMenuPlanner
//
//  Created by Ilia Khokhlov on 30.09.25.
//

import Foundation

#if canImport(AmplitudeSwift)
import AmplitudeSwift
#endif

/// An AnalyticsProvider backed by Amplitude. If the Amplitude SDK isn't linked,
/// this provider will safely no-op.
public final class AmplitudeAnalyticsProvider: AnalyticsProvider {
    #if canImport(AmplitudeSwift)
    private var client: Amplitude?
    #endif

    private var isTrackingEnabled: Bool = true

    public init() {}

    public func start(configuration: [String : Any]) {
        guard isTrackingEnabled else { return }
        #if canImport(AmplitudeSwift)
        // Build API key from configuration (single key or environment-mapped keys)
        var apiKeyToUse: String?
        if let apiKey = configuration["apiKey"] as? String {
            apiKeyToUse = apiKey
        } else if let apiKeys = configuration["apiKeys"] as? [String: String],
                  let env = configuration["environment"] as? String,
                  let key = apiKeys[env] {
            apiKeyToUse = key
        }

        guard let apiKey = apiKeyToUse else { return }

        let config = Configuration(apiKey: apiKey, autocapture: [.sessions, .appLifecycles])
        
        config.enableCoppaControl = true
        let options = TrackingOptions()
            .disableTrackDMA()
            .disableTrackRegion()
            .disableTrackCarrier()
        config.trackingOptions = options
        
        let amplitude = Amplitude(configuration: config)
        self.client = amplitude

        if let userId = configuration["userId"] as? String {
            amplitude.setUserId(userId: userId)
        }
        #endif
    }

    public func identify(userId: String?, traits: [String : Sendable]) {
        guard isTrackingEnabled else { return }
        #if canImport(AmplitudeSwift)
        guard let client = self.client else { return }
        if let userId = userId {
            client.setUserId(userId: userId)
        }
        if !traits.isEmpty {
            let identify = Identify()
            for (key, value) in traits {
                if let v = value as? String {
                    identify.set(property: key, value: v)
                } else if let v = value as? Int {
                    identify.set(property: key, value: v)
                } else if let v = value as? Double {
                    identify.set(property: key, value: v)
                } else if let v = value as? Bool {
                    identify.set(property: key, value: v)
                } else {
                    identify.set(property: key, value: String(describing: value))
                }
            }
            client.identify(identify: identify)
        }
        #endif
    }

    public func track(_ event: AnalyticsEvent) {
        guard isTrackingEnabled else { return }
        #if canImport(AmplitudeSwift)
        guard let client = self.client else { return }
        var props: [String: Any] = [:]
        for (k, v) in event.properties {
            if let value = v as? any CustomStringConvertible {
                props[k] = value.description
            } else if let value = v as? NSNumber {
                props[k] = value
            } else if let value = v as? String {
                props[k] = value
            } else if let value = v as? Int {
                props[k] = value
            } else if let value = v as? Double {
                props[k] = value
            } else if let value = v as? Bool {
                props[k] = value
            } else {
                props[k] = String(describing: v)
            }
        }
        client.track(eventType: event.name, eventProperties: props)
        #endif
    }

    public func setUserProperty(_ key: String, value: Sendable?) {
        guard isTrackingEnabled else { return }
        #if canImport(AmplitudeSwift)
        guard let client = self.client else { return }
        let identify = Identify()
        if let value = value {
            if let v = value as? String {
                identify.set(property: key, value: v)
            } else if let v = value as? Int {
                identify.set(property: key, value: v)
            } else if let v = value as? Double {
                identify.set(property: key, value: v)
            } else if let v = value as? Bool {
                identify.set(property: key, value: v)
            } else {
                identify.set(property: key, value: String(describing: value))
            }
        } else {
            identify.unset(property: key)
        }
        client.identify(identify: identify)
        #endif
    }

    public func setUserProperties(_ properties: [String : Sendable]) {
        guard isTrackingEnabled else { return }
        #if canImport(AmplitudeSwift)
        guard let client = self.client else { return }
        let identify = Identify()
        for (key, value) in properties {
            if let v = value as? String {
                identify.set(property: key, value: v)
            } else if let v = value as? Int {
                identify.set(property: key, value: v)
            } else if let v = value as? Double {
                identify.set(property: key, value: v)
            } else if let v = value as? Bool {
                identify.set(property: key, value: v)
            } else {
                identify.set(property: key, value: String(describing: value))
            }
        }
        client.identify(identify: identify)
        #endif
    }

    public func logRevenue(_ revenue: AnalyticsRevenue) {
        guard isTrackingEnabled else { return }
        #if canImport(AmplitudeSwift)
        guard let client = self.client else { return }
        let ampRevenue = Revenue()
        ampRevenue.price = revenue.price
        ampRevenue.quantity = revenue.quantity
        if let productId = revenue.productId {
            ampRevenue.productId = productId
        }
        if let currency = revenue.currency {
            ampRevenue.currency = currency
        }
        client.revenue(revenue: ampRevenue)
        #endif
    }

    public func setTrackingEnabled(_ enabled: Bool) {
        isTrackingEnabled = enabled
        #if canImport(AmplitudeSwift)
        client?.optOut = !enabled
        #endif
    }
}

