import XCTest
import CloudKit
@testable import FamilyMenuPlanner

final class CloudKitSeedingGateUnitTests: XCTestCase {
    override func setUpWithError() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Skipping CloudKitSeedingGate tests on simulator")
        #endif
    }
    func testWaitForImportOrTimeoutTimesOut() async {
        let didImport = await CloudKitSeedingGate.waitForImportOrTimeout(timeout: 0.05)
        XCTAssertFalse(didImport)
    }

    func testWaitForImportOrRemoteEmptyTimesOutQuickly() async {
        // Small maxWait to avoid any real CloudKit polling - function should return .timedOut
        let outcome = await CloudKitSeedingGate.waitForImportOrRemoteEmpty(maxWait: 0.2)
        XCTAssertEqual(outcome, .timedOut)
    }
}


final class CloudKitSeedingGatePureTests: XCTestCase {
    func testVersionSatisfiesWhenEqual() {
        XCTAssertTrue(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: "1.1", required: "1.1"))
    }

    func testVersionDoesNotSatisfyWhenNil() {
        XCTAssertFalse(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: nil, required: "1.1"))
    }

    func testVersionDoesNotSatisfyWhenEmpty() {
        XCTAssertFalse(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: "", required: "1.1"))
    }

    func testVersionDoesNotSatisfyWhenDifferent() {
        XCTAssertFalse(CloudKitSeedingGate.doesStoredSeedVersionSatisfy(stored: "1.0", required: "1.1"))
    }
}


final class CloudKitSeedingLeaseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testLeaseWithoutTimestampIsStale() {
        XCTAssertTrue(CloudKitSeedingGate.isLeaseStale(leaseDate: nil, now: now))
    }

    func testFreshLeaseIsNotStale() {
        XCTAssertFalse(CloudKitSeedingGate.isLeaseStale(leaseDate: now.addingTimeInterval(-60), now: now))
    }

    func testLeaseOlderThanIntervalIsStale() {
        let leaseDate = now.addingTimeInterval(-(CloudKitSeedingGate.staleLeaseInterval + 1))
        XCTAssertTrue(CloudKitSeedingGate.isLeaseStale(leaseDate: leaseDate, now: now))
    }

    func testGateUsesEntitledContainerNotBundleDefault() {
        XCTAssertEqual(CloudKitSeedingGate.containerIdentifier, "iCloud.container.menu")
        XCTAssertEqual(LiveCloudKitSeedingService().containerIdentifier, "iCloud.container.menu")
    }
}

final class CloudKitSeedingLeaseAcquisitionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func existingLease(age: TimeInterval) -> CKRecord {
        let record = CKRecord(recordType: CloudKitSeedingGate.seedAnchorRecordName,
                              recordID: CKRecord.ID(recordName: CloudKitSeedingGate.seedAnchorRecordName))
        record["timestamp"] = now.addingTimeInterval(-age) as CKRecordValue
        return record
    }

    func testCreatesLeaseWhenNoneExists() async {
        let database = MockRecordDatabase()

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertTrue(acquired)
        XCTAssertEqual(database.savedRecords.count, 1)
        XCTAssertEqual(database.savedRecords.first?["timestamp"] as? Date, now)
    }

    func testFreshLeaseHeldByAnotherDeviceIsNotAcquired() async {
        let database = MockRecordDatabase()
        database.serverRecord = existingLease(age: 60)

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertFalse(acquired)
        XCTAssertEqual(database.savedRecords.count, 1, "Only the create attempt, no takeover")
    }

    func testStaleLeaseIsTakenOverByUpdatingServerRecord() async {
        let database = MockRecordDatabase()
        let server = existingLease(age: CloudKitSeedingGate.staleLeaseInterval + 60)
        database.serverRecord = server

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertTrue(acquired)
        XCTAssertEqual(database.savedRecords.count, 2)
        // The takeover saves the fetched server record (carrying its change tag), not a fresh one
        XCTAssertTrue(database.savedRecords.last === server)
        XCTAssertEqual(server["timestamp"] as? Date, now)
    }

    func testCompetingTakeoverIsRejected() async {
        let database = MockRecordDatabase()
        database.serverRecord = existingLease(age: CloudKitSeedingGate.staleLeaseInterval + 60)
        // Another device updates the lease between our fetch and our save
        database.rejectTakeover = true

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertFalse(acquired)
    }

    func testSaveErrorDoesNotAcquireLease() async {
        let database = MockRecordDatabase()
        database.createError = CKError(.networkUnavailable)

        let acquired = await CloudKitSeedingGate.tryAcquireSeedingLease(now: now, database: database)

        XCTAssertFalse(acquired)
    }
}

final class CloudKitSeedMarkerTests: XCTestCase {
    private func marker(version: String) -> CKRecord {
        let record = CKRecord(recordType: CloudKitSeedingGate.seededVersionRecordName,
                              recordID: CKRecord.ID(recordName: CloudKitSeedingGate.seededVersionRecordName))
        record["version"] = version as CKRecordValue
        return record
    }

    func testShouldWriteSeedMarker() {
        XCTAssertTrue(CloudKitSeedingGate.shouldWriteSeedMarker(stored: nil, new: "1.1"))
        XCTAssertTrue(CloudKitSeedingGate.shouldWriteSeedMarker(stored: "", new: "1.1"))
        XCTAssertTrue(CloudKitSeedingGate.shouldWriteSeedMarker(stored: "1.1", new: "1.2"))
        XCTAssertTrue(CloudKitSeedingGate.shouldWriteSeedMarker(stored: "1.9", new: "1.10"))
        XCTAssertFalse(CloudKitSeedingGate.shouldWriteSeedMarker(stored: "1.1", new: "1.1"))
        XCTAssertFalse(CloudKitSeedingGate.shouldWriteSeedMarker(stored: "1.2", new: "1.1"))
        XCTAssertFalse(CloudKitSeedingGate.shouldWriteSeedMarker(stored: "1.10", new: "1.9"))
    }

    func testCreatesMarkerWhenMissing() async {
        let database = MockMarkerDatabase()

        let written = await CloudKitSeedingGate.markAccountSeeded(version: "1.1", database: database)

        XCTAssertTrue(written)
        XCTAssertEqual(database.serverRecord?["version"] as? String, "1.1")
    }

    func testUpdatesOlderMarkerInPlace() async {
        let database = MockMarkerDatabase()
        let server = marker(version: "1.0")
        database.serverRecord = server

        let written = await CloudKitSeedingGate.markAccountSeeded(version: "1.1", database: database)

        XCTAssertTrue(written)
        XCTAssertTrue(database.savedRecords.last === server, "Updates the fetched record so the save carries its change tag")
        XCTAssertEqual(server["version"] as? String, "1.1")
    }

    func testDoesNotDowngradeNewerMarker() async {
        let database = MockMarkerDatabase()
        database.serverRecord = marker(version: "1.2")

        let written = await CloudKitSeedingGate.markAccountSeeded(version: "1.1", database: database)

        XCTAssertFalse(written)
        XCTAssertTrue(database.savedRecords.isEmpty)
        XCTAssertEqual(database.serverRecord?["version"] as? String, "1.2")
    }

    func testFetchErrorDoesNotWrite() async {
        let database = MockMarkerDatabase()
        database.fetchError = CKError(.networkUnavailable)

        let written = await CloudKitSeedingGate.markAccountSeeded(version: "1.1", database: database)

        XCTAssertFalse(written)
        XCTAssertTrue(database.savedRecords.isEmpty)
    }
}

private final class MockMarkerDatabase: CloudKitRecordStoring {
    var serverRecord: CKRecord?
    var fetchError: Error?
    private(set) var savedRecords: [CKRecord] = []

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        if let fetchError { throw fetchError }
        guard let serverRecord else { throw CKError(.unknownItem) }
        return serverRecord
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        savedRecords.append(record)
        serverRecord = record
        return record
    }
}

final class CloudKitRemoteEmptinessProbeTests: XCTestCase {
    private func page(records: Bool, moreComing: Bool) -> ZoneChangesPage {
        ZoneChangesPage(hasRecords: records, moreComing: moreComing, changeToken: nil)
    }

    func testZoneWithRecordsIsNotEmpty() async {
        let reader = MockZoneChangeReader(results: [.success(page(records: true, moreComing: false))])
        let empty = await CloudKitSeedingGate.coreDataZoneAppearsEmpty(reader: reader)
        XCTAssertFalse(empty)
    }

    func testZoneWithoutRecordsIsEmpty() async {
        let reader = MockZoneChangeReader(results: [.success(page(records: false, moreComing: false))])
        let empty = await CloudKitSeedingGate.coreDataZoneAppearsEmpty(reader: reader)
        XCTAssertTrue(empty)
    }

    func testMissingZoneIsEmpty() async {
        let reader = MockZoneChangeReader(results: [.failure(CKError(.zoneNotFound))])
        let empty = await CloudKitSeedingGate.coreDataZoneAppearsEmpty(reader: reader)
        XCTAssertTrue(empty)
    }

    func testTransportErrorIsNotEmpty() async {
        let reader = MockZoneChangeReader(results: [.failure(CKError(.networkFailure))])
        let empty = await CloudKitSeedingGate.coreDataZoneAppearsEmpty(reader: reader)
        XCTAssertFalse(empty)
    }

    func testRecordOnLaterPageIsNotEmpty() async {
        let reader = MockZoneChangeReader(results: [
            .success(page(records: false, moreComing: true)),
            .success(page(records: true, moreComing: false))
        ])
        let empty = await CloudKitSeedingGate.coreDataZoneAppearsEmpty(reader: reader)
        XCTAssertFalse(empty)
        XCTAssertEqual(reader.callCount, 2)
    }

    func testPagingBeyondLimitIsNotEmpty() async {
        let pages = Array(repeating: Result<ZoneChangesPage, Error>.success(page(records: false, moreComing: true)),
                          count: CloudKitSeedingGate.maxProbePages + 1)
        let reader = MockZoneChangeReader(results: pages)
        let empty = await CloudKitSeedingGate.coreDataZoneAppearsEmpty(reader: reader)
        XCTAssertFalse(empty)
        XCTAssertEqual(reader.callCount, CloudKitSeedingGate.maxProbePages)
    }
}

private final class MockZoneChangeReader: CloudKitZoneChangeReading {
    private var results: [Result<ZoneChangesPage, Error>]
    private(set) var callCount = 0

    init(results: [Result<ZoneChangesPage, Error>]) {
        self.results = results
    }

    func zoneChangesPage(in zoneID: CKRecordZone.ID, since changeToken: CKServerChangeToken?) async throws -> ZoneChangesPage {
        callCount += 1
        XCTAssertEqual(zoneID, CloudKitSeedingGate.coreDataZoneID)
        return try results.removeFirst().get()
    }
}

/// Mimics `.ifServerRecordUnchanged` saves of a single record
private final class MockRecordDatabase: CloudKitRecordSaving {
    /// The lease already on the server, if any
    var serverRecord: CKRecord?
    var createError: Error?
    var rejectTakeover = false
    private(set) var savedRecords: [CKRecord] = []

    func save(_ record: CKRecord) async throws -> CKRecord {
        savedRecords.append(record)
        if let createError { throw createError }
        if let serverRecord {
            if record === serverRecord && !rejectTakeover {
                return record
            }
            throw CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: serverRecord])
        }
        serverRecord = record
        return record
    }
}
