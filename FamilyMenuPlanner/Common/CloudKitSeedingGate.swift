@preconcurrency import Foundation
import CoreData
import CloudKit

enum CloudKitSeedingGate {
    /// Default maximum time to wait for CloudKit import before declaring timeout
    static let defaultMaxWait: TimeInterval = 180
    /// Default record type prefix used by NSPersistentCloudKitContainer for mirrored entities
    private static let cloudKitRecordPrefix: String = "CD_"
    /// A minimal set of Core Data entity names that should exist in any real dataset
    /// Kept as entity names to avoid duplicating the CloudKit prefix in many places
    private static let probeEntityNames: [String] = ["Unit", "Product", "MealType", "DishCategory", "Dish"]
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

    /// Indefinitely waits for CloudKit import completion, or within a maxWait window
    /// probes remote for emptiness of Core Data mirror and returns an outcome.
    /// This is conservative: it will only allow seeding when remote clearly appears empty.
    @MainActor
    static func waitForImportOrRemoteEmpty(maxWait: TimeInterval = CloudKitSeedingGate.defaultMaxWait) async -> GateOutcome {
        let start = Date()

        // Start remote emptiness probe as a long-running task
        async let remoteEmpty: Bool = Self.probeRemoteEmptiness(start: start, maxWait: maxWait)

        // Tick in short intervals racing import vs. remote emptiness without blocking on either
        while Date().timeIntervalSince(start) < maxWait {
            // If an import completes during this small window, finish immediately
            if await Self.waitForImportOrTimeout(timeout: 0.2) {
                return .importCompleted
            }

            // If remote appears empty before an import arrives, allow seeding
            if await remoteEmpty {
                return .remoteAppearsEmpty
            }
        }

        return .timedOut
    }

    /// Polls CloudKit mirror for any presence of records within a window.
    /// Returns true if the mirror appears empty before the timeout elapses.
    private static func probeRemoteEmptiness(start: Date, maxWait: TimeInterval) async -> Bool {
        // Probe a small set of record types commonly present in the mirror
        // Build record types from entity names using the configured/default prefix
        let probeTypes = Self.probeEntityNames.map { Self.cloudKitRecordPrefix + $0 }
        var delay: TimeInterval = 2
        while Date().timeIntervalSince(start) < maxWait {
            if await remoteStoreAppearsEmpty(recordTypes: probeTypes) {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay = min(delay * 1.5, 10)
        }
        return false
    }

    /// Best-effort probe of CloudKit mirror to see if any Core Data mirrored records exist.
    /// Returns true if none of the provided record types have any records.
    private static func remoteStoreAppearsEmpty(recordTypes: [String]) async -> Bool {
        // If iCloud is unavailable or status cannot be determined, DO NOT treat as empty
        // to avoid accidental local seeding that later conflicts with CloudKit import.
        do {
            let status = try await CKContainer.default().accountStatus()
            if status != .available { return false }
        } catch {
            return false
        }

        let db = CKContainer.default().privateCloudDatabase
        for type in recordTypes {
            let hadAny = await hasAnyRecord(ofType: type, in: db)
            if hadAny { return false }
        }
        return true
    }

    private static func hasAnyRecord(ofType type: String, in db: CKDatabase) async -> Bool {
        await withCheckedContinuation { continuation in
            let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
            let op = CKQueryOperation(query: query)
            op.resultsLimit = 1
            var found = false
            op.recordMatchedBlock = { _, result in
                if case .success = result { found = true }
            }
            op.queryResultBlock = { _ in
                continuation.resume(returning: found)
            }
            db.add(op)
        }
    }

    /// Attempts to create a small anchor record in CloudKit to "lease" seeding.
    /// Returns true if lease acquired (record created), false if record already exists or on error.
    static func tryAcquireSeedingLease() async -> Bool {
        do {
            let db = CKContainer.default().privateCloudDatabase
            let recordID = CKRecord.ID(recordName: "FM_SeedAnchor")
            let record = CKRecord(recordType: "FM_SeedAnchor", recordID: recordID)
            record["timestamp"] = Date() as CKRecordValue
            return try await withCheckedThrowingContinuation { continuation in
                db.save(record) { _, error in
                    if let ckError = error as? CKError {
                        if ckError.code == .serverRecordChanged || ckError.code == .batchRequestFailed || ckError.code == .unknownItem {
                            // Treat as not acquired if exists/changed
                            continuation.resume(returning: false)
                            return
                        }
                    }
                    if error != nil {
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: true)
                    }
                }
            }
        } catch {
            return false
        }
    }

    /// Returns true if the account already has the given seed version recorded.
    /// The check validates the stored CloudKit record's `version` field equals the requested `version`.
    /// If the record is missing, or the stored version differs (or is missing), returns false.
    static func isAccountSeeded(version: String) async -> Bool {
        do {
            let db = CKContainer.default().privateCloudDatabase
            let recordID = CKRecord.ID(recordName: "FM_SeededVersion")
            return try await withCheckedThrowingContinuation { continuation in
                db.fetch(withRecordID: recordID) { record, error in
                    if let record, error == nil {
                        let storedVersion = record["version"] as? String
                        continuation.resume(returning: Self.doesStoredSeedVersionSatisfy(stored: storedVersion, required: version))
                        return
                    }
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        continuation.resume(returning: false)
                        return
                    }
                    continuation.resume(returning: false)
                }
            }
        } catch {
            return false
        }
    }

    /// Pure helper to decide whether a stored seed version satisfies the required version.
    /// Currently strict-equality; can be extended to semantic version precedence if needed.
    static func doesStoredSeedVersionSatisfy(stored: String?, required: String) -> Bool {
        guard let stored = stored, !stored.isEmpty else { return false }
        return stored == required
    }

    /// Marks the account as seeded for the specified version. Idempotent.
    static func markAccountSeeded(version: String) async {
        do {
            let db = CKContainer.default().privateCloudDatabase
            let recordID = CKRecord.ID(recordName: "FM_SeededVersion")
            let record = CKRecord(recordType: "FM_SeededVersion", recordID: recordID)
            record["version"] = version as CKRecordValue
            record["timestamp"] = Date() as CKRecordValue
            _ = try await withCheckedThrowingContinuation { continuation in
                db.save(record) { _, _ in
                    continuation.resume(returning: ())
                }
            }
        } catch {
            // best-effort; ignore errors
        }
    }
}


