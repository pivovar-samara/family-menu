import XCTest
import CloudKit
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



// MARK: - First-launch seeding flow

@MainActor
final class AppStateManagerSeedingFlowTests: XCTestCase {
    private var service: MockCloudKitSeedingService!
    private var store: MockStartupDataStore!

    override func setUp() async throws {
        try await super.setUp()
        service = MockCloudKitSeedingService()
        store = MockStartupDataStore()
    }

    override func tearDown() async throws {
        service = nil
        store = nil
        try await super.tearDown()
    }

    private func makeManager(startupMode: StartupMode = .cloudKitAware) -> AppStateManager {
        AppStateManager(
            seedingService: service,
            dataStore: store,
            startupMode: startupMode,
            seedingGateMaxWait: 1,
            seedingGateRetryDelay: 0
        )
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    func testICloudUnavailableSeedsImmediately() async {
        service.accountStatusResult = .success(.noAccount)

        let manager = makeManager()

        let finished = await waitUntil { !manager.isLoading }
        XCTAssertTrue(finished)
        XCTAssertFalse(manager.isICloudAvailable)
        XCTAssertEqual(store.generateCallCount, 1)
        XCTAssertEqual(service.isAccountSeededCallCount, 0)
        XCTAssertEqual(service.waitCallCount, 0)
        XCTAssertTrue(service.markedVersions.isEmpty)
    }

    func testAccountStatusErrorSeedsLocally() async {
        service.accountStatusResult = .failure(CKError(.networkUnavailable))

        let manager = makeManager()

        let finished = await waitUntil { !manager.isLoading }
        XCTAssertTrue(finished)
        XCTAssertFalse(manager.isICloudAvailable)
        XCTAssertEqual(store.generateCallCount, 1)
        XCTAssertEqual(service.waitCallCount, 0)
    }

    func testLocalOnlyModeSkipsAccountCheckAndSeeds() async {
        let manager = makeManager(startupMode: .localOnly)

        let finished = await waitUntil { !manager.isLoading }
        XCTAssertTrue(finished)
        XCTAssertEqual(service.accountStatusCallCount, 0)
        XCTAssertEqual(store.generateCallCount, 1)
    }

    func testSkippedModeDoesNothing() {
        let manager = makeManager(startupMode: .skipped)

        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(service.accountStatusCallCount, 0)
        XCTAssertEqual(store.generateCallCount, 0)
    }

    func testGateDecidesOnlyAfterAccountStatusResolves() async {
        let manager = makeManager()

        // The account status has not resolved yet, so nothing may be seeded
        XCTAssertTrue(manager.isLoading)
        XCTAssertEqual(store.generateCallCount, 0)

        let gated = await waitUntil { self.service.waitCallCount == 1 }
        XCTAssertTrue(gated)
        XCTAssertEqual(store.generateCallCount, 0)
    }

    func testAccountAlreadySeededDoesNotSeedLocally() async {
        service.isAccountSeededResult = true
        service.waitOutcomes = [.remoteAppearsEmpty]

        let manager = makeManager()

        // A second round starting means the first one finished without seeding
        let rearmed = await waitUntil { self.service.waitCallCount == 2 }
        XCTAssertTrue(rearmed)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(service.leaseCallCount, 0)
        XCTAssertTrue(manager.isLoading)
    }

    func testImportCompletedDoesNotSeedLocally() async {
        service.waitOutcomes = [.importCompleted]
        service.onWait = { [store] in store?.isEmpty = false }

        let manager = makeManager()

        let finished = await waitUntil { !manager.isLoading }
        XCTAssertTrue(finished)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(store.didFinishLoadingCallCount, 1)
        XCTAssertEqual(service.leaseCallCount, 0)
        XCTAssertTrue(service.markedVersions.isEmpty)
    }

    func testRemoteEmptyAndLeaseAcquiredSeedsAndMarksAccount() async {
        service.waitOutcomes = [.remoteAppearsEmpty]
        service.leaseResult = true

        let manager = makeManager()

        let marked = await waitUntil { !self.service.markedVersions.isEmpty }
        XCTAssertTrue(marked)
        XCTAssertEqual(service.markedVersions, [store.preloadDataVersion])
        XCTAssertEqual(store.generateCallCount, 1)
        XCTAssertEqual(service.leaseCallCount, 1)
        XCTAssertFalse(manager.isLoading)
    }

    func testRemoteEmptyAndLeaseNotAcquiredKeepsWaiting() async {
        service.waitOutcomes = [.remoteAppearsEmpty]
        service.leaseResult = false

        let manager = makeManager()

        let rearmed = await waitUntil { self.service.waitCallCount == 2 }
        XCTAssertTrue(rearmed)
        XCTAssertEqual(service.leaseCallCount, 1)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertTrue(manager.isLoading)
    }

    func testTimeoutKeepsLoadingWithoutSeeding() async {
        service.waitOutcomes = [.timedOut]

        let manager = makeManager()

        let rearmed = await waitUntil { self.service.waitCallCount == 2 }
        XCTAssertTrue(rearmed)
        XCTAssertEqual(service.leaseCallCount, 0)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertTrue(manager.isLoading)
    }

    func testNoGatingWhenStoreDoesNotMirrorToCloudKit() async {
        store.cloudKitContainerIdentifier = nil

        let manager = makeManager()

        let finished = await waitUntil { !manager.isLoading }
        XCTAssertTrue(finished)
        XCTAssertEqual(service.waitCallCount, 0)
        XCTAssertEqual(store.generateCallCount, 1)
        XCTAssertTrue(service.markedVersions.isEmpty)
    }
}

// MARK: - Mocks

@MainActor
private final class MockCloudKitSeedingService: CloudKitSeedingService {
    let containerIdentifier = "iCloud.container.menu"
    var accountStatusResult: Result<CKAccountStatus, Error> = .success(.available)
    var isAccountSeededResult = false
    /// Outcomes returned by successive waits; once exhausted, waits suspend until cancelled
    var waitOutcomes: [CloudKitSeedingGate.GateOutcome] = []
    var onWait: (() -> Void)?
    var leaseResult = false

    private(set) var accountStatusCallCount = 0
    private(set) var isAccountSeededCallCount = 0
    private(set) var waitCallCount = 0
    private(set) var leaseCallCount = 0
    private(set) var markedVersions: [String] = []

    func accountStatus() async throws -> CKAccountStatus {
        accountStatusCallCount += 1
        return try accountStatusResult.get()
    }

    func isAccountSeeded(version: String) async -> Bool {
        isAccountSeededCallCount += 1
        return isAccountSeededResult
    }

    func waitForImportOrRemoteEmpty(maxWait: TimeInterval) async -> CloudKitSeedingGate.GateOutcome {
        waitCallCount += 1
        guard !waitOutcomes.isEmpty else {
            try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            return .timedOut
        }
        onWait?()
        return waitOutcomes.removeFirst()
    }

    func tryAcquireSeedingLease() async -> Bool {
        leaseCallCount += 1
        return leaseResult
    }

    func markAccountSeeded(version: String) async {
        markedVersions.append(version)
    }
}

@MainActor
private final class MockStartupDataStore: StartupDataStore {
    var isReady = true
    var userFriendlyErrorMessage: String? = nil
    var cloudKitContainerIdentifier: String? = "iCloud.container.menu"
    let preloadDataVersion = "1.1"
    var isEmpty = true

    private(set) var generateCallCount = 0
    private(set) var didFinishLoadingCallCount = 0

    func isDatabaseEmpty() -> Bool { isEmpty }
    func needsDataPopulation() -> Bool { isEmpty }
    func performStartupMaintenance() {}

    func generateInitialData(isCloudImportInProgress: Bool, completion: @escaping (Bool) -> Void) {
        generateCallCount += 1
        isEmpty = false
        completion(true)
    }

    func didFinishLoading() { didFinishLoadingCallCount += 1 }

    func attemptRecovery(completion: @escaping (Bool) -> Void) { completion(true) }
}
