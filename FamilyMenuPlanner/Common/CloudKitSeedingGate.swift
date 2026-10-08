@preconcurrency import Foundation
import CoreData
import CloudKit

/// CloudKit calls used by `AppStateManager` to gate first-launch seeding.
/// The live implementation is `LiveCloudKitSeedingService`; tests inject a mock.
protocol CloudKitSeedingService {
    /// Identifier of the CloudKit container the calls go to
    var containerIdentifier: String { get }
    func accountStatus() async throws -> CKAccountStatus
    func isAccountSeeded(version: String) async -> Bool
    @MainActor func waitForImportOrRemoteEmpty(maxWait: TimeInterval) async -> CloudKitSeedingGate.GateOutcome
    func tryAcquireSeedingLease() async -> Bool
    func markAccountSeeded(version: String) async
}

struct LiveCloudKitSeedingService: CloudKitSeedingService {
    var containerIdentifier: String { CloudKitSeedingGate.containerIdentifier }

    func accountStatus() async throws -> CKAccountStatus {
        try await CloudKitSeedingGate.container.accountStatus()
    }

    func isAccountSeeded(version: String) async -> Bool {
        await CloudKitSeedingGate.isAccountSeeded(version: version)
    }

    @MainActor
    func waitForImportOrRemoteEmpty(maxWait: TimeInterval) async -> CloudKitSeedingGate.GateOutcome {
        await CloudKitSeedingGate.waitForImportOrRemoteEmpty(maxWait: maxWait)
    }

    func tryAcquireSeedingLease() async -> Bool {
        await CloudKitSeedingGate.tryAcquireSeedingLease()
    }

    func markAccountSeeded(version: String) async {
        await CloudKitSeedingGate.markAccountSeeded(version: version)
    }
}

enum CloudKitSeedingGate {
    /// The container NSPersistentCloudKitContainer mirrors to (first entry of
    /// `com.apple.developer.icloud-container-identifiers`). Do not use `CKContainer.default()` here:
    /// it resolves to `iCloud.<bundle id>` (`iCloud.com.pivovar.FamilyMenuPlanner`), which the app is
    /// not entitled to, so every call against it fails.
    static let containerIdentifier = "iCloud.container.menu"
    static let container = CKContainer(identifier: containerIdentifier)
    /// Zone where NSPersistentCloudKitContainer stores the mirrored `CD_*` records
    static let coreDataZoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
    /// Marker record (private DB, `_defaultZone`) holding the preload version the account was seeded with
    static let seededVersionRecordName = "FM_SeededVersion"
    /// Lease record (private DB, `_defaultZone`) created by the device that is seeding
    static let seedAnchorRecordName = "FM_SeedAnchor"
    /// A lease older than this is treated as abandoned (the seeding device crashed or went offline)
    /// and can be taken over. Local seeding takes seconds and the first export well under a minute.
    static let staleLeaseInterval: TimeInterval = 10 * 60

    /// Default maximum time to wait for CloudKit import before declaring timeout.
    /// 3 minutes is a conservative window observed to cover slow but healthy
    /// first-time iCloud imports on older devices and congested networks.
    /// Callers can override this by passing a custom `maxWait` to
    /// `waitForImportOrRemoteEmpty(maxWait:)` if a different trade‑off is desired.
    static let defaultMaxWait: TimeInterval = 180
    /// Upper bound on zone-change pages read while probing the mirror for emptiness
    private static let maxProbePages = 5
    /// Waits for the first NSPersistentCloudKitContainer import event or a timeout.
    /// Returns true if an import completed, false if timed out.
    static func waitForImportOrTimeout(timeout: TimeInterval) async -> Bool {
        let center = NotificationCenter.default
        let importCompleted = AsyncStream<Void> { continuation in
            let token = center.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                   event.type == .import,
                   event.endDate != nil {
                    continuation.yield(())
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                center.removeObserver(token)
            }
        }

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { for await _ in importCompleted { return true }; return false }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)); return false }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    enum GateOutcome {
        case importCompleted
        case remoteAppearsEmpty
        case timedOut
    }

    /// Waits for CloudKit import completion, or within a maxWait window
    /// probes remote for emptiness of Core Data mirror and returns an outcome.
    /// This is conservative: it will only allow seeding when remote clearly appears empty.
    @MainActor
    static func waitForImportOrRemoteEmpty(maxWait: TimeInterval = CloudKitSeedingGate.defaultMaxWait) async -> GateOutcome {
        let start = Date()
        let deadline = start.addingTimeInterval(maxWait)

        // Race three outcomes concurrently: import completion, remote emptiness, or timeout
        return await withTaskGroup(of: GateOutcome.self) { group in
            group.addTask {
                let didImport = await Self.waitForImportOrTimeout(timeout: maxWait)
                return didImport ? .importCompleted : .timedOut
            }

            group.addTask {
                let empty = await Self.probeRemoteEmptiness(start: start, maxWait: maxWait)
                return empty ? .remoteAppearsEmpty : .timedOut
            }

            group.addTask {
                let remaining = max(0, deadline.timeIntervalSinceNow)
                if remaining > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                }
                return .timedOut
            }

            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
    }

    /// Polls the CloudKit mirror within a window.
    /// Returns true if the mirror appears empty before the timeout elapses.
    private static func probeRemoteEmptiness(start: Date, maxWait: TimeInterval) async -> Bool {
        var delay: TimeInterval = 2
        while Date().timeIntervalSince(start) < maxWait {
            if Task.isCancelled { return false }
            if await remoteStoreAppearsEmpty() {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return false }
            delay = min(delay * 1.5, 10)
        }
        return false
    }

    /// Best-effort probe of the Core Data mirror zone.
    /// Returns true only when the zone is known to hold no records; any error means "unknown" and returns false,
    /// so a failed probe never unlocks local seeding.
    ///
    /// Reads zone changes instead of running a `CKQuery`: queries need a queryable `recordName` index,
    /// which the Core Data schema does not declare, so a query would always fail.
    private static func remoteStoreAppearsEmpty() async -> Bool {
        do {
            let status = try await container.accountStatus()
            if status != .available {
                AppLogger.info("Remote emptiness probe: iCloud account status \(status.rawValue) – treating remote as unknown", category: AppLogger.cloudKit)
                return false
            }
        } catch {
            logCloudKitError("Remote emptiness probe: account status check failed", error)
            return false
        }

        let db = container.privateCloudDatabase
        var changeToken: CKServerChangeToken? = nil
        for _ in 0..<maxProbePages {
            if Task.isCancelled { return false }
            do {
                let changes = try await db.recordZoneChanges(inZoneWith: coreDataZoneID, since: changeToken, desiredKeys: [], resultsLimit: 1)
                if !changes.modificationResultsByID.isEmpty {
                    return false
                }
                if !changes.moreComing {
                    AppLogger.info("Remote emptiness probe: Core Data zone has no records", category: AppLogger.cloudKit)
                    return true
                }
                changeToken = changes.changeToken
            } catch let error as CKError where error.code == .zoneNotFound {
                AppLogger.info("Remote emptiness probe: Core Data zone does not exist yet", category: AppLogger.cloudKit)
                return true
            } catch {
                logCloudKitError("Remote emptiness probe failed – treating remote as not empty", error)
                return false
            }
        }
        return false
    }

    /// Attempts to create a small anchor record in CloudKit to "lease" seeding.
    /// Returns true if the lease was acquired: the record was created, or an existing lease older than
    /// `staleLeaseInterval` was taken over. Returns false if another device holds a fresh lease or on error.
    static func tryAcquireSeedingLease(now: Date = Date()) async -> Bool {
        let db = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: seedAnchorRecordName)
        let record = CKRecord(recordType: seedAnchorRecordName, recordID: recordID)
        record["timestamp"] = now as CKRecordValue
        do {
            _ = try await db.save(record)
            AppLogger.info("Seeding lease record created", category: AppLogger.cloudKit)
            return true
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let existing = error.serverRecord else {
                logCloudKitError("Seeding lease exists but server record is missing from the error", error)
                return false
            }
            let leaseDate = existing["timestamp"] as? Date
            guard isLeaseStale(leaseDate: leaseDate, now: now) else {
                AppLogger.info("Seeding lease held by another device since \(leaseDate.map { "\($0)" } ?? "unknown")", category: AppLogger.cloudKit)
                return false
            }
            // Take over by updating the fetched record: the save carries its change tag,
            // so if another device takes over at the same time only one save succeeds.
            existing["timestamp"] = now as CKRecordValue
            do {
                _ = try await db.save(existing)
                AppLogger.warning("Took over stale seeding lease from \(leaseDate.map { "\($0)" } ?? "unknown")", category: AppLogger.cloudKit)
                return true
            } catch {
                logCloudKitError("Failed to take over stale seeding lease", error)
                return false
            }
        } catch {
            logCloudKitError("Failed to create seeding lease", error)
            return false
        }
    }

    /// Pure helper: a lease without a timestamp, or older than `staleAfter`, is abandoned.
    static func isLeaseStale(leaseDate: Date?, now: Date, staleAfter: TimeInterval = staleLeaseInterval) -> Bool {
        guard let leaseDate else { return true }
        return now.timeIntervalSince(leaseDate) > staleAfter
    }

    /// Returns true if the account already has the given seed version recorded.
    /// The check validates the stored CloudKit record's `version` field equals the requested `version`.
    /// If the record is missing, or the stored version differs (or is missing), returns false.
    static func isAccountSeeded(version: String) async -> Bool {
        let db = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: seededVersionRecordName)
        do {
            let record = try await db.record(for: recordID)
            let storedVersion = record["version"] as? String
            AppLogger.info("Account seed marker found with version \(storedVersion ?? "nil")", category: AppLogger.cloudKit)
            return doesStoredSeedVersionSatisfy(stored: storedVersion, required: version)
        } catch let error as CKError where error.code == .unknownItem {
            AppLogger.info("Account seed marker not found", category: AppLogger.cloudKit)
            return false
        } catch {
            logCloudKitError("Failed to fetch account seed marker", error)
            return false
        }
    }

    /// Pure helper to decide whether a stored seed version satisfies the required version.
    /// Currently strict-equality; can be extended to semantic version precedence if needed.
    static func doesStoredSeedVersionSatisfy(stored: String?, required: String) -> Bool {
        guard let stored = stored, !stored.isEmpty else { return false }
        return stored == required
    }

    /// Marks the account as seeded for the specified version. Idempotent: overwrites an existing marker
    /// (`.allKeys` save policy), so a marker from an older preload version does not fail with `.serverRecordChanged`.
    static func markAccountSeeded(version: String) async {
        let db = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: seededVersionRecordName)
        let record = CKRecord(recordType: seededVersionRecordName, recordID: recordID)
        record["version"] = version as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        do {
            let result = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
            if case .failure(let error)? = result.saveResults[recordID] {
                logCloudKitError("Failed to save account seed marker", error)
                return
            }
            AppLogger.info("Account marked seeded with version \(version) in \(containerIdentifier)", category: AppLogger.cloudKit)
        } catch {
            logCloudKitError("Failed to save account seed marker", error)
        }
    }

    private static func logCloudKitError(_ message: String, _ error: Error) {
        let code = (error as? CKError).map { "CKError code \($0.code.rawValue)" } ?? "non-CloudKit error"
        AppLogger.error("\(message) [\(code), container \(containerIdentifier)]", error: error, category: AppLogger.cloudKit)
    }
}
