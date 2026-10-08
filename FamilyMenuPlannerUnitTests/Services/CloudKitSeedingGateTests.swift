import XCTest
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
