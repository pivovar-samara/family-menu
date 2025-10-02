//
//  AnalyticsBootstrap.swift
//  FamilyMenuPlanner
//
//  Created by Ilia Khokhlov on 30.09.25.
//

import Foundation

/// Helper to set up the analytics system at app launch.
public enum AnalyticsBootstrap {
    /// Configure the shared AnalyticsManager with providers and start them.
    /// - Parameters:
    ///   - amplitudeApiKey: Optional Amplitude API key. If nil, the provider is not added.
    ///   - environment: Optional environment string used when passing a map of API keys.
    ///   - additionalProviders: Any additional providers to include.
    ///   - initialUserId: Optional initial user id to set on providers that support it.
    ///   - additionalConfiguration: Extra configuration bag forwarded to all providers.
    public static func configure(amplitudeApiKey: String? = nil,
                                 environment: String? = nil,
                                 additionalProviders: [AnalyticsProvider] = [],
                                 initialUserId: String? = nil,
                                 additionalConfiguration: [String: Any] = [:]) {
        var providers: [AnalyticsProvider] = []

        if let _ = amplitudeApiKey {
            providers.append(AmplitudeAnalyticsProvider())
        }

        providers.append(contentsOf: additionalProviders)

        AnalyticsManager.shared.configure(providers: providers)

        var config = additionalConfiguration
        if let apiKey = amplitudeApiKey {
            config["apiKey"] = apiKey
        }
        if let environment = environment {
            config["environment"] = environment
        }
        if let userId = initialUserId {
            config["userId"] = userId
        }

        AnalyticsManager.shared.start(configuration: config)
    }
}
