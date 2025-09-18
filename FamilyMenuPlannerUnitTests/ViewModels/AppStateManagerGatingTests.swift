import XCTest
@testable import FamilyMenuPlanner

final class AppStateManagerGatingTests: XCTestCase {
    func testGatingOccursWhenCloudKitAvailableCloudContainerEmptyNoLease() {
        XCTAssertTrue(AppSeedingGating.shouldGateSeeding(
            isICloudAvailable: true,
            isCloudKitContainer: true,
            isDatabaseEmpty: true,
            hasSeedingLease: false
        ))
    }

    func testNoGatingWhenNoCloudKit() {
        XCTAssertFalse(AppSeedingGating.shouldGateSeeding(
            isICloudAvailable: false,
            isCloudKitContainer: true,
            isDatabaseEmpty: true,
            hasSeedingLease: false
        ))
    }

    func testNoGatingWhenNotCloudKitContainer() {
        XCTAssertFalse(AppSeedingGating.shouldGateSeeding(
            isICloudAvailable: true,
            isCloudKitContainer: false,
            isDatabaseEmpty: true,
            hasSeedingLease: false
        ))
    }

    func testNoGatingWhenDatabaseNotEmpty() {
        XCTAssertFalse(AppSeedingGating.shouldGateSeeding(
            isICloudAvailable: true,
            isCloudKitContainer: true,
            isDatabaseEmpty: false,
            hasSeedingLease: false
        ))
    }

    func testLeaseBypassesGatingEvenIfOtherwiseGated() {
        XCTAssertFalse(AppSeedingGating.shouldGateSeeding(
            isICloudAvailable: true,
            isCloudKitContainer: true,
            isDatabaseEmpty: true,
            hasSeedingLease: true
        ))
    }
}


