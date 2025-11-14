import Foundation
import UIKit

/// Thread-safe in-memory ring buffer for capturing recent logs produced by AppLogger.
/// This is intentionally minimal and local to diagnostics to avoid a separate LogBuffer type.
public final class AppLogCapture {
    public static let shared = AppLogCapture()
    private let queue = DispatchQueue(label: "com.familymenuplanner.AppLogCapture", qos: .utility)
    private var messages: [String] = []
    private let capacity: Int = 1000

    private init() {}
    
    /// Shared ISO8601 date formatter for timestamps (thread-safe).
    public static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    /// Append a new log line with timestamp.
    public func append(_ message: String) {
        let ts = Self.timestampFormatter.string(from: Date())
        let line = "[\(ts)] \(message)"
        queue.async { [weak self] in
            guard let self = self else { return }
            self.messages.reserveCapacity(min(self.messages.count + 1, self.capacity))
            if self.messages.count >= self.capacity {
                self.messages.removeFirst(self.messages.count - self.capacity + 1)
            }
            self.messages.append(line)
        }
    }

    /// Returns the last N log lines (default 50). Thread-safe snapshot.
    public func tail(_ count: Int = 50) -> [String] {
        var result: [String] = []
        queue.sync {
            let start = max(self.messages.count - count, 0)
            result = Array(self.messages[start..<self.messages.count])
        }
        return result
    }
}

/// Helper for building and encoding diagnostics information for support.
public enum DiagnosticsHelper {
    /// Builds a diagnostics dictionary and encodes it to pretty-printed JSON data.
    /// - Parameter logsTailCount: Number of last log lines to include (default: 50)
    /// - Returns: Tuple with JSON Data and a suggested filename, or nil if encoding fails.
    public static func diagnosticsJSONData(logsTailCount: Int = 50) -> (data: Data, filename: String)? {
        let dict = diagnosticsDictionary(logsTailCount: logsTailCount)
        guard JSONSerialization.isValidJSONObject(dict) else {
            // Coerce values to JSON-safe by converting any non-JSON types to strings
            let jsonSafe = makeJSONSafe(dict)
            guard JSONSerialization.isValidJSONObject(jsonSafe) else { return nil }
            return encode(jsonSafe)
        }
        return encode(dict)
    }

    /// Builds a dictionary with app, device, and environment details.
    /// Values intentionally exclude personally identifiable information (PII).
    public static func diagnosticsDictionary(logsTailCount: Int = 50) -> [String: Any] {
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = info?["CFBundleVersion"] as? String ?? ""

        var dict: [String: Any] = [:]
        dict["app_version"] = appVersion
        dict["build_number"] = buildNumber
        dict["ios_version"] = UIDevice.current.systemVersion
        dict["device_model"] = deviceModelIdentifier() // model identifier like "iPhone16,1"
        dict["locale"] = Locale.current.identifier
        dict["timestamp"] = AppLogCapture.timestampFormatter.string(from: Date())
        dict["logs_tail"] = AppLogCapture.shared.tail(logsTailCount)
        return dict
    }

    private static func encode(_ object: Any) -> (data: Data, filename: String)? {
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            let ts = filenameTimestamp()
            let filename = "diagnostics-\(ts).json"
            return (data, filename)
        } catch {
            return nil
        }
    }

    private static func filenameTimestamp() -> String {
        // ISO-like, but avoid characters that are problematic for filenames
        let formatter = AppLogCapture.timestampFormatter
        var ts = formatter.string(from: Date())
        // Replace ":" with "-" to be safe for filenames
        ts = ts.replacingOccurrences(of: ":", with: "-")
        return ts
    }

    /// Returns a device model identifier such as "iPhone16,1" without including the user-defined device name.
    private static func deviceModelIdentifier() -> String {
        // Prefer model identifier via sysctl
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        if !identifier.isEmpty {
            return identifier
        }
        // Fallback to generic model
        return UIDevice.current.model
    }

    /// Recursively converts non-JSON types to strings so JSONSerialization can encode them.
    private static func makeJSONSafe(_ object: Any) -> Any {
        switch object {
        case let dict as [String: Any]:
            var result: [String: Any] = [:]
            for (k, v) in dict { result[k] = makeJSONSafe(v) }
            return result
        case let array as [Any]:
            return array.map { makeJSONSafe($0) }
        case let date as Date:
            return AppLogCapture.timestampFormatter.string(from: date)
        case is String, is NSNumber, is NSNull:
            return object
        default:
            return String(describing: object)
        }
    }
}

