import XCTest
import CloudKit
import UIKit
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
        service.holdsAccountStatus = true

        let manager = makeManager()

        let requested = await waitUntil { self.service.isAccountStatusPending }
        XCTAssertTrue(requested)
        // Give the startup task time to (wrongly) move on while the status is unresolved
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(manager.isLoading)
        XCTAssertEqual(service.isAccountSeededCallCount, 0)
        XCTAssertEqual(service.waitCallCount, 0)
        XCTAssertEqual(store.generateCallCount, 0)

        service.resumeAccountStatus()

        let gated = await waitUntil { self.service.waitCallCount == 1 }
        XCTAssertTrue(gated)
        XCTAssertTrue(manager.isICloudAvailable)
        XCTAssertEqual(store.generateCallCount, 0)
    }

    func testAccountAlreadySeededDoesNotSeedLocally() async {
        service.isAccountSeededResult = .seeded
        service.waitOutcomes = [.remoteAppearsEmpty]

        let manager = makeManager()

        // A second round starting means the first one finished without seeding
        let rearmed = await waitUntil { self.service.waitCallCount == 2 }
        XCTAssertTrue(rearmed)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(service.leaseCallCount, 0)
        XCTAssertTrue(manager.isLoading)
    }

    func testUnreadableSeedMarkerDoesNotSeedLocally() async {
        service.isAccountSeededResult = .unknown
        service.waitOutcomes = [.remoteAppearsEmpty]
        service.leaseResult = true

        let manager = makeManager()

        let rearmed = await waitUntil { self.service.waitCallCount == 2 }
        XCTAssertTrue(rearmed)
        XCTAssertEqual(service.leaseCallCount, 0)
        XCTAssertEqual(store.generateCallCount, 0)
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

    func testDataArrivingWithoutImportEventEndsGate() async {
        // The import finished but its notification was missed: the round times out with data already in the store
        service.waitOutcomes = [.timedOut]
        service.onWait = { [store] in store?.isEmpty = false }

        let manager = makeManager()

        let finished = await waitUntil { !manager.isLoading }
        XCTAssertTrue(finished)
        XCTAssertEqual(service.waitCallCount, 1)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(store.didFinishLoadingCallCount, 1)
    }

    func testIncompleteGenerationDoesNotMarkAccountSeeded() async {
        service.waitOutcomes = [.remoteAppearsEmpty]
        service.leaseResult = true
        store.generationCompletesPreload = false

        let manager = makeManager()

        let finished = await waitUntil { !manager.isLoading }
        XCTAssertTrue(finished)
        XCTAssertEqual(store.generateCallCount, 1)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(service.markedVersions.isEmpty)
    }

    func testRetryAfterFailedSeedReacquiresLease() async {
        service.waitOutcomes = [.remoteAppearsEmpty]
        service.leaseResult = true
        store.generationSucceeds = false

        let manager = makeManager()

        let failed = await waitUntil { manager.showPersistenceErrorAlert }
        XCTAssertTrue(failed)
        XCTAssertEqual(store.generateCallCount, 1)

        manager.retryPersistenceSetup()

        // The used lease no longer bypasses the gate: the retry starts a new gate round instead of seeding
        let regated = await waitUntil { self.service.waitCallCount == 2 }
        XCTAssertTrue(regated)
        XCTAssertEqual(store.generateCallCount, 1)
        XCTAssertTrue(manager.isLoading)
    }

    func testPartialDataDuringImportWaitsInsteadOfSeeding() async {
        service.holdsAccountStatus = true
        store.isEmpty = false
        store.isPartial = true

        let manager = makeManager()
        let requested = await waitUntil { self.service.isAccountStatusPending }
        XCTAssertTrue(requested)
        manager.isCloudKitSyncing = true
        service.resumeAccountStatus()

        let checked = await waitUntil { self.service.accountStatusCallCount == 1 && !self.service.isAccountStatusPending }
        XCTAssertTrue(checked)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertTrue(manager.isLoading)
    }

    func testLeaseSurvivesImportInProgressAndSeedsAfterIt() async {
        service.waitOutcomes = [.remoteAppearsEmpty]
        service.leaseResult = true
        service.holdsAccountStatus = true

        let manager = makeManager()
        let requested = await waitUntil { self.service.isAccountStatusPending }
        XCTAssertTrue(requested)
        // An import (e.g. the container's initial setup import) is running when the lease is granted
        manager.isCloudKitSyncing = true
        service.resumeAccountStatus()

        let deferred = await waitUntil { self.service.leaseCallCount == 1 }
        XCTAssertTrue(deferred)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(store.generateCallCount, 0)

        // Import finished: the post-import check must seed with the lease still held, without a new gate round
        manager.isCloudKitSyncing = false
        manager.recheckDatabaseStateForTesting()

        let seeded = await waitUntil { self.store.generateCallCount == 1 }
        XCTAssertTrue(seeded)
        XCTAssertEqual(service.waitCallCount, 1)
        XCTAssertEqual(service.leaseCallCount, 1)
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

// MARK: - Recovery after an iCloud account change purges the store

@MainActor
final class AppStateManagerAccountChangeTests: XCTestCase {
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

    private func makeManager() -> AppStateManager {
        AppStateManager(
            seedingService: service,
            dataStore: store,
            startupMode: .cloudKitAware,
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

    /// Launches with a populated store and waits until startup has finished loading it
    private func launchWithData() async -> AppStateManager {
        store.isEmpty = false
        let manager = makeManager()
        let loaded = await waitUntil { !manager.isLoading }
        XCTAssertTrue(loaded)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(store.didFinishLoadingCallCount, 1)
        return manager
    }

    /// Longer than the settle delay of the recheck, for asserting that nothing happened
    private func waitPastRecheck() async {
        try? await Task.sleep(nanoseconds: 800_000_000)
    }

    func testPurgeAfterICloudTurnedOffSeedsPreloadDataLocally() async {
        // iCloud already off at launch; the container purges the old account's data during setup, after startup
        service.accountStatusResult = .success(.noAccount)
        let manager = await launchWithData()

        store.isEmpty = true
        manager.cloudKitSetupDidFinishForTesting()

        let reseeded = await waitUntil { self.store.generateCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(reseeded)
        XCTAssertFalse(manager.isICloudAvailable)
        XCTAssertEqual(service.accountStatusCallCount, 2)
        XCTAssertEqual(service.waitCallCount, 0)
        XCTAssertTrue(service.markedVersions.isEmpty)
        XCTAssertEqual(store.didFinishLoadingCallCount, 2)
        XCTAssertGreaterThanOrEqual(store.reloadAfterResetCallCount, 1)
    }

    func testSignOutWhileRunningSeedsLocallyAfterPurge() async {
        let manager = await launchWithData()
        XCTAssertTrue(manager.isICloudAvailable)

        // iCloud turned off for the app while it runs: account change, then the purge
        service.accountStatusResult = .success(.noAccount)
        store.isEmpty = true
        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)

        let reseeded = await waitUntil { self.store.generateCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(reseeded)
        XCTAssertFalse(manager.isICloudAvailable)
        XCTAssertEqual(service.waitCallCount, 0)
        XCTAssertTrue(service.markedVersions.isEmpty)
    }

    func testPurgeAfterSwitchingAccountsGoesThroughSeedingGate() async {
        let manager = await launchWithData()

        // Another account is signed in: the old account's data is purged
        store.isEmpty = true
        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)

        let gated = await waitUntil { self.service.waitCallCount == 1 }
        XCTAssertTrue(gated)
        XCTAssertTrue(manager.isICloudAvailable)
        XCTAssertTrue(manager.isLoading)
        XCTAssertEqual(service.isAccountSeededCallCount, 1)
        XCTAssertEqual(store.generateCallCount, 0)
    }

    func testAccountChangeWithDataStillPresentDoesNotReseed() async {
        let manager = await launchWithData()

        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)

        let rechecked = await waitUntil { self.service.accountStatusCallCount == 2 }
        XCTAssertTrue(rechecked)
        await waitPastRecheck()
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(store.didFinishLoadingCallCount, 1)
        XCTAssertEqual(service.waitCallCount, 0)
    }

    func testSetupFinishedWithPopulatedStoreDoesNothing() async {
        let manager = await launchWithData()

        manager.cloudKitSetupDidFinishForTesting()

        await waitPastRecheck()
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(service.accountStatusCallCount, 1)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(store.didFinishLoadingCallCount, 1)
        // The view context (which may hold unsaved edits) is left alone when nothing was purged
        XCTAssertEqual(store.reloadAfterResetCallCount, 0)
    }

    func testAccountChangeDuringSeedingGateReplacesGateOfPreviousAccount() async {
        // Empty store with iCloud available: startup waits in the gate (the wait never returns)
        let manager = makeManager()
        let gated = await waitUntil { self.service.waitCallCount == 1 }
        XCTAssertTrue(gated)

        service.accountStatusResult = .success(.noAccount)
        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)

        let seeded = await waitUntil { self.store.generateCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(seeded)
        XCTAssertEqual(service.waitCallCount, 1)
        XCTAssertTrue(service.markedVersions.isEmpty)
    }

    func testSetupFinishedBeforeAccountStatusIsLeftToStartup() async {
        service.holdsAccountStatus = true
        store.isEmpty = false
        let manager = makeManager()
        let requested = await waitUntil { self.service.isAccountStatusPending }
        XCTAssertTrue(requested)

        manager.cloudKitSetupDidFinishForTesting()
        await waitPastRecheck()
        XCTAssertEqual(service.accountStatusCallCount, 1)

        service.resumeAccountStatus()
        let loaded = await waitUntil { !manager.isLoading }
        XCTAssertTrue(loaded)
        XCTAssertEqual(service.accountStatusCallCount, 1)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(store.reloadAfterResetCallCount, 1)
    }

    func testPurgeDuringSetupBeforeAccountStatusIsSeenByStartupCheck() async {
        // iCloud off at launch; setup purges the store while the account lookup is pending,
        // but the view context still shows the pre-purge data until it is refreshed
        service.holdsAccountStatus = true
        service.accountStatusResult = .success(.noAccount)
        store.isEmpty = false
        store.isEmptyAfterReload = true
        let manager = makeManager()
        let requested = await waitUntil { self.service.isAccountStatusPending }
        XCTAssertTrue(requested)

        manager.cloudKitSetupDidFinishForTesting()
        service.resumeAccountStatus()

        let seeded = await waitUntil { self.store.generateCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(seeded)
        XCTAssertEqual(service.waitCallCount, 0)
    }

    func testPurgeAfterAccountChangeIsCaughtWhenAppBecomesActive() async {
        // iCloud turned off while the app is in the background: the account change is handled before the purge
        let manager = await launchWithData()
        service.accountStatusResult = .success(.noAccount)
        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)
        let rechecked = await waitUntil { self.service.accountStatusCallCount == 2 }
        XCTAssertTrue(rechecked)
        await waitPastRecheck()
        XCTAssertEqual(store.generateCallCount, 0)

        // The purge lands later; the app comes back to the foreground
        store.isEmpty = true
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let reseeded = await waitUntil { self.store.generateCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(reseeded)
        XCTAssertFalse(manager.isICloudAvailable)
        XCTAssertEqual(service.waitCallCount, 0)
    }

    func testPurgeSeenAsRemoteStoreChangeReseeds() async {
        service.accountStatusResult = .success(.noAccount)
        let manager = await launchWithData()

        store.isEmpty = true
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)

        let reseeded = await waitUntil(timeout: 5) { self.store.generateCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(reseeded)
        XCTAssertEqual(service.waitCallCount, 0)
    }

    func testStoreChangeWithPartialDataAndICloudOnLeavesItToImport() async {
        let manager = await launchWithData()

        // Partly imported data while iCloud is on: not a purge
        store.isPartial = true
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let rechecked = await waitUntil { self.service.accountStatusCallCount == 2 }
        XCTAssertTrue(rechecked)
        await waitPastRecheck()
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(service.waitCallCount, 0)
    }

    func testDataArrivingDuringLookupRetryClearsLoading() async {
        let manager = await launchWithData()

        // Purged, and the account lookup fails: the loading screen stays up while retrying
        service.accountStatusResult = .failure(CKError(.networkUnavailable))
        store.isEmpty = true
        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)
        let waiting = await waitUntil { self.service.accountStatusCallCount >= 2 && manager.isLoading }
        XCTAssertTrue(waiting)

        // Data arrives (e.g. imported) before the lookup succeeds
        store.isEmpty = false
        let loaded = await waitUntil { !manager.isLoading }
        XCTAssertTrue(loaded)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(store.didFinishLoadingCallCount, 2)
    }

    func testICloudTurnedOnWhileRunningRestartsMirroring() async {
        // Launched without iCloud (mirroring setup failed), local preload data in the store
        service.accountStatusResult = .success(.noAccount)
        let manager = await launchWithData()

        // iCloud turned on for the app in Settings; turning it on posts no CKAccountChanged
        service.accountStatusResult = .success(.available)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let restarted = await waitUntil { self.store.storeReloadCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(restarted)
        XCTAssertTrue(manager.isICloudAvailable)
        XCTAssertEqual(store.didFinishLoadingCallCount, 2)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertEqual(service.waitCallCount, 0)
    }

    func testActivationWithICloudStillOffDoesNotReloadStore() async {
        service.accountStatusResult = .success(.noAccount)
        let manager = await launchWithData()

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let rechecked = await waitUntil { self.service.accountStatusCallCount == 2 }
        XCTAssertTrue(rechecked)
        await waitPastRecheck()
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(store.storeReloadCallCount, 0)
        XCTAssertEqual(store.generateCallCount, 0)
    }

    func testActivationWithICloudOnDoesNotCheckAccount() async {
        let manager = await launchWithData()

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await waitPastRecheck()
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(service.accountStatusCallCount, 1)
        XCTAssertEqual(store.storeReloadCallCount, 0)
        XCTAssertEqual(store.reloadAfterResetCallCount, 0)
    }

    func testFailedStoreReloadShowsError() async {
        service.accountStatusResult = .success(.noAccount)
        let manager = await launchWithData()
        store.storeReloadSucceeds = false

        service.accountStatusResult = .success(.available)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let failed = await waitUntil { manager.showPersistenceErrorAlert }
        XCTAssertTrue(failed)
        XCTAssertFalse(manager.isLoading)
    }

    func testFailedAccountLookupAfterPurgeRetriesInsteadOfSeeding() async {
        let manager = await launchWithData()

        // Account changed and the store was purged, but the status lookup fails (e.g. offline)
        service.accountStatusResult = .failure(CKError(.networkUnavailable))
        store.isEmpty = true
        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)

        let retried = await waitUntil { self.service.accountStatusCallCount >= 3 }
        XCTAssertTrue(retried)
        XCTAssertEqual(store.generateCallCount, 0)
        XCTAssertTrue(manager.isLoading)

        // The lookup succeeds once connectivity returns: iCloud is off, so seed locally
        service.accountStatusResult = .success(.noAccount)
        let seeded = await waitUntil { self.store.generateCallCount == 1 && !manager.isLoading }
        XCTAssertTrue(seeded)
        XCTAssertFalse(manager.isICloudAvailable)
        XCTAssertEqual(service.waitCallCount, 0)
    }
}

// MARK: - Startup mode detection

final class StartupModeDetectionTests: XCTestCase {
    func testNormalLaunchIsCloudKitAware() {
        XCTAssertEqual(StartupMode.detect(environment: [:], arguments: ["FamilyMenuPlanner"], isXCTestLoaded: false), .cloudKitAware)
    }

    func testCIEnvironmentIsSkipped() {
        XCTAssertEqual(StartupMode.detect(environment: ["CI": "TRUE"], arguments: [], isXCTestLoaded: false), .skipped)
        XCTAssertEqual(StartupMode.detect(environment: ["GITHUB_ACTIONS": "true"], arguments: [], isXCTestLoaded: false), .skipped)
    }

    func testXcodeCloudBuildNumberIsSkipped() {
        XCTAssertEqual(StartupMode.detect(environment: ["BUILD_NUMBER": "42"], arguments: [], isXCTestLoaded: false), .skipped)
    }

    func testHostedXCTestIsSkipped() {
        XCTAssertEqual(StartupMode.detect(environment: ["XCTestConfigurationFilePath": "/tmp/x"], arguments: [], isXCTestLoaded: true), .skipped)
    }

    func testCIWinsOverUITestFlags() {
        XCTAssertEqual(StartupMode.detect(environment: ["CI": "TRUE"], arguments: ["-UITests", "-DisableCloudKit"], isXCTestLoaded: false), .skipped)
    }

    func testUITestLaunchIsLocalOnly() {
        XCTAssertEqual(StartupMode.detect(environment: [:], arguments: ["FamilyMenuPlanner", "-UITests", "-DisableCloudKit"], isXCTestLoaded: false), .localOnly)
    }

    func testDisableCloudKitIsLocalOnly() {
        XCTAssertEqual(StartupMode.detect(environment: [:], arguments: ["-DisableCloudKit"], isXCTestLoaded: false), .localOnly)
    }

    func testEnvironmentSwitchesAreLocalOnly() {
        XCTAssertEqual(StartupMode.detect(environment: ["UI_TESTS": "1"], arguments: [], isXCTestLoaded: false), .localOnly)
        XCTAssertEqual(StartupMode.detect(environment: ["DISABLE_CLOUDKIT": "1"], arguments: [], isXCTestLoaded: false), .localOnly)
    }

    func testLoadedXCTestWithoutConfigurationIsLocalOnly() {
        XCTAssertEqual(StartupMode.detect(environment: [:], arguments: [], isXCTestLoaded: true), .localOnly)
    }
}

// MARK: - Mocks

@MainActor
private final class MockCloudKitSeedingService: CloudKitSeedingService {
    let containerIdentifier = "iCloud.container.menu"
    var accountStatusResult: Result<CKAccountStatus, Error> = .success(.available)
    /// When true, `accountStatus()` suspends until `resumeAccountStatus()` is called
    var holdsAccountStatus = false
    private var accountStatusContinuation: CheckedContinuation<Void, Never>?
    var isAccountStatusPending: Bool { accountStatusContinuation != nil }
    var isAccountSeededResult: CloudKitSeedingGate.SeedMarkerStatus = .notSeeded
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
        if holdsAccountStatus {
            await withCheckedContinuation { accountStatusContinuation = $0 }
        }
        return try accountStatusResult.get()
    }

    func resumeAccountStatus() {
        accountStatusContinuation?.resume()
        accountStatusContinuation = nil
    }

    func isAccountSeeded(version: String) async -> CloudKitSeedingGate.SeedMarkerStatus {
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
    /// Some reference data present but the current preload is incomplete (partial import)
    var isPartial = false
    var generationSucceeds = true
    /// Whether a successful generation leaves the complete current preload in the store
    var generationCompletesPreload = true

    private(set) var generateCallCount = 0
    private(set) var didFinishLoadingCallCount = 0
    private(set) var reloadAfterResetCallCount = 0

    func isDatabaseEmpty() -> Bool { isEmpty }
    func needsDataPopulation() -> Bool { isEmpty || isPartial }
    func storeNeedsDataPopulation() -> Bool { needsDataPopulation() }
    func hasCurrentPreloadData() -> Bool { !isEmpty && !isPartial }
    func performStartupMaintenance() {}

    func generateInitialData(isCloudImportInProgress: Bool, completion: @escaping (Bool) -> Void) {
        generateCallCount += 1
        if generationSucceeds {
            isEmpty = false
            isPartial = !generationCompletesPreload
        }
        completion(generationSucceeds)
    }

    func didFinishLoading() { didFinishLoadingCallCount += 1 }
    /// Store contents the refreshed view context sees (a purge that had not reached the view context yet)
    var isEmptyAfterReload: Bool?

    var storeReloadSucceeds = true
    private(set) var storeReloadCallCount = 0

    func reloadStoreForCloudKitMirroring(completion: @escaping (Bool) -> Void) {
        storeReloadCallCount += 1
        completion(storeReloadSucceeds)
    }

    func reloadAfterStoreReset() {
        reloadAfterResetCallCount += 1
        if let isEmptyAfterReload { isEmpty = isEmptyAfterReload }
    }

    func attemptRecovery(completion: @escaping (Bool) -> Void) { completion(true) }
}
