//
//  AppStateManager.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 13.01.25.
//

@preconcurrency import Foundation
import CoreData
import SwiftUI
import CloudKit

@MainActor
final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    private var cloudKitEventObserver: NSObjectProtocol? = nil
    private var accountChangeObserver: NSObjectProtocol? = nil
    private var storeChangeObservers: [NSObjectProtocol] = []
    private var storeChangeDebounceTask: Task<Void, Never>?
    /// Incremented on every iCloud account change; a seed started before the change must not mark the new account
    private var accountGeneration = 0
    /// Set while a mirroring restart waits for unsaved edits to be saved or discarded
    private var deferredRestartSaveObserver: NSObjectProtocol?
    /// Small delay that allows CloudKit merge operations to fully settle
    private static let cloudKitMergeSettleDelay: TimeInterval = 0.5
    
    @Published var isLoading: Bool = true
    @Published var isICloudAvailable: Bool = false
    @Published var isCloudKitSyncing: Bool = false
    @Published var persistenceError: String? = nil
    @Published var showPersistenceErrorAlert: Bool = false
    private var isDatabaseEmpty: Bool = false
    /// When true, we have acquired a CloudKit seeding lease and must bypass the CloudKit gating
    /// to proceed with local initial data generation to avoid an infinite wait loop.
    private var hasCloudKitSeedingLease: Bool = false

    private let seedingService: CloudKitSeedingService
    private let dataStore: StartupDataStore
    private let seedingGateMaxWait: TimeInterval
    /// Pause between gate rounds that ended without a decision, so a quick "keep waiting" does not spin
    private let seedingGateRetryDelay: TimeInterval
    private var startupTask: Task<Void, Never>?
    /// False until the iCloud account status is known; import events must not trigger a database check before that
    private var isAccountStatusResolved = false
    private var seedingGateTask: Task<Void, Never>?
    /// Re-check after an iCloud account change or a finished CloudKit setup (see `recheckAfterStoreReset`)
    private var storeResetRecheckTask: Task<Void, Never>?
    /// A CloudKit setup finished (and may have purged the store) before the account status was known
    private var hasStoreResetBeforeStartupCheck = false

    private convenience init() {
        self.init(
            seedingService: LiveCloudKitSeedingService(),
            dataStore: PersistenceStartupDataStore(),
            startupMode: .detect()
        )
    }

    init(seedingService: CloudKitSeedingService,
         dataStore: StartupDataStore,
         startupMode: StartupMode,
         seedingGateMaxWait: TimeInterval = CloudKitSeedingGate.defaultMaxWait,
         seedingGateRetryDelay: TimeInterval = 15) {
        self.seedingService = seedingService
        self.dataStore = dataStore
        self.seedingGateMaxWait = seedingGateMaxWait
        self.seedingGateRetryDelay = seedingGateRetryDelay

        switch startupMode {
        case .skipped:
            print("ℹ️ AppStateManager: Running in CI environment")
            // Set safe defaults for CI
            self.isLoading = false
            self.isICloudAvailable = false
        case .localOnly:
            AppLogger.info("AppStateManager initializing...", category: AppLogger.appState)
            AppLogger.debug("Running in test/CI environment - skipping iCloud account status check", category: AppLogger.appState)
            self.isICloudAvailable = false
            checkPersistenceState()
            AppLogger.info("AppStateManager initialized successfully", category: AppLogger.appState)
        case .cloudKitAware:
            AppLogger.info("AppStateManager initializing...", category: AppLogger.appState)
            // The seeding decision depends on iCloud availability, so resolve the account status first
            // and keep the loading screen up meanwhile.
            // Observe import events from the start so an import that begins during the account check is not missed
            observeCloudKitEvents()
            observeAccountChanges()
            observeStoreChanges()
            startupTask = Task { [weak self] in
                await self?.resolveICloudAccountStatus()
                guard let self else { return }
                self.isAccountStatusResolved = true
                if self.hasStoreResetBeforeStartupCheck, self.dataStore.isReady {
                    // The view context may still show the store from before the purge
                    self.hasStoreResetBeforeStartupCheck = false
                    self.dataStore.reloadAfterStoreReset()
                }
                self.checkPersistenceState()
            }
        }
    }
    
    deinit {
        startupTask?.cancel()
        seedingGateTask?.cancel()
        storeResetRecheckTask?.cancel()
        storeChangeDebounceTask?.cancel()
        storeChangeObservers.forEach { NotificationCenter.default.removeObserver($0) }
        if let token = deferredRestartSaveObserver {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = cloudKitEventObserver {
            NotificationCenter.default.removeObserver(token)
            cloudKitEventObserver = nil
        }
        if let token = accountChangeObserver {
            NotificationCenter.default.removeObserver(token)
            accountChangeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkPersistenceState() {
        if !dataStore.isReady {
            // Handle persistence errors
            self.persistenceError = dataStore.userFriendlyErrorMessage
            self.showPersistenceErrorAlert = true
            self.isLoading = false
            return
        }
        
        // If persistence is ready, continue with normal flow
        checkDatabaseState()
    }
    
    func retryPersistenceSetup() {
        self.persistenceError = nil
        self.showPersistenceErrorAlert = false
        self.isLoading = true
        
        // Use the new asynchronous recovery method to avoid blocking the UI
        dataStore.attemptRecovery { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.checkDatabaseState()
                } else {
                    self?.persistenceError = "Unable to recover from the error. Please restart the app or contact support if the problem persists.".localized()
                    self?.showPersistenceErrorAlert = true
                    self?.isLoading = false
                }
            }
        }
    }

    /// Returns false when the status could not be read. Then iCloud counts as unavailable, unless
    /// `keepAvailabilityOnFailure` keeps the previous value (a failed lookup must not unlock ungated seeding).
    @discardableResult
    private func resolveICloudAccountStatus(keepAvailabilityOnFailure: Bool = false) async -> Bool {
        do {
            let status = try await seedingService.accountStatus()
            // A replaced recheck's lookup may finish after the current one: do not publish its result
            guard !Task.isCancelled else { return false }
            self.isICloudAvailable = (status == .available)
            if self.isICloudAvailable {
                AppLogger.info("iCloud is available - CloudKit sync enabled", category: AppLogger.cloudKit)
                AnalyticsManager.shared.setUserProperties([AnalyticsUserPropertyName.icloud_available: true])
                if let mirrorContainer = dataStore.cloudKitContainerIdentifier,
                   mirrorContainer != seedingService.containerIdentifier {
                    AppLogger.error("Core Data mirrors to \(mirrorContainer) but seeding gate uses \(seedingService.containerIdentifier)", category: AppLogger.cloudKit)
                }
            } else {
                AppLogger.info("iCloud is not available (account status \(status.rawValue)) - running in local mode", category: AppLogger.cloudKit)
                AnalyticsManager.shared.setUserProperties([AnalyticsUserPropertyName.icloud_available: false])
            }
            return true
        } catch {
            guard !Task.isCancelled else { return false }
            AppLogger.error("iCloud account check failed [\(CloudKitSeedingGate.errorCodeDescription(error)), container \(seedingService.containerIdentifier)]", error: error, category: AppLogger.cloudKit)
            AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "iCloud account check failed")
            if !keepAvailabilityOnFailure {
                AnalyticsManager.shared.setUserProperties([AnalyticsUserPropertyName.icloud_available: false])
                self.isICloudAvailable = false
            }
            return false
        }
    }

    private func observeCloudKitEvents() {
        guard cloudKitEventObserver == nil else { return }
        // Observe CloudKit events via classic observer to avoid non-sendable Notification in Swift 6
        cloudKitEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleCloudKitEvent(notification)
            }
        }
    }

    /// Signing out of iCloud, switching accounts, or turning off iCloud for the app (which CloudKit treats as a sign-out)
    private func observeAccountChanges() {
        guard accountChangeObserver == nil else { return }
        accountChangeObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                AppLogger.info("iCloud account changed", category: AppLogger.cloudKit)
                self?.recheckAfterStoreReset(trigger: .accountChanged)
            }
        }
    }

    /// The purge after an account change can come later than the account-change notification and the setup
    /// event (e.g. iCloud turned off while the app is in the background), so also re-check when the app becomes
    /// active and after remote store changes (the purge is one)
    private func observeStoreChanges() {
        guard storeChangeObservers.isEmpty else { return }
        let center = NotificationCenter.default
        storeChangeObservers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recheckAfterStoreReset(trigger: .storeChanged)
            }
        })
        storeChangeObservers.append(center.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRecheckAfterRemoteChange()
            }
        })
    }

    /// Debounces a burst of remote-change notifications into one re-check
    private func scheduleRecheckAfterRemoteChange() {
        storeChangeDebounceTask?.cancel()
        storeChangeDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.storeChangeDebounceTask = nil
            // An import in progress is rechecked when it completes
            guard !self.isCloudKitSyncing else { return }
            self.recheckAfterStoreReset(trigger: .storeChanged)
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
        switch event.type {
        case .setup:
            // After an account change (or iCloud turned off for the app) the container purges the mirrored
            // local data while setting up, which can be after startup already found the store populated
            if event.endDate != nil {
                if let error = event.error {
                    AppLogger.info("CloudKit setup finished with error [\(CloudKitSeedingGate.errorCodeDescription(error))]", category: AppLogger.cloudKit)
                }
                recheckAfterStoreReset(trigger: .setupFinished)
            }
        case .import:
            if event.endDate == nil {
                isCloudKitSyncing = true
            } else if event.endDate != nil {
                isCloudKitSyncing = false
                AppLogger.info("iCloud sync completed", category: AppLogger.cloudKit)
                // Slight delay allows final merges to settle to avoid repeated reprocessing
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.cloudKitMergeSettleDelay) {
                    if PersistenceController.shared.isReady {
                        let bg = PersistenceController.shared.newBackgroundContext()
                        bg.perform {
                            // Call helpers on the background context's queue
                            PersistenceController.shared.normalizeDishMealTypeRelations(context: bg)
                            PersistenceController.shared.normalizeDishProductRelations(context: bg)
                            // Remove duplicate reference data first
                            PersistenceController.shared.cleanupDuplicateUnits(context: bg)
                            PersistenceController.shared.cleanupDuplicateMealTypes(context: bg)
                            PersistenceController.shared.cleanupDuplicateDishCategories(context: bg)
                            PersistenceController.shared.cleanupDuplicateProducts(context: bg)
                            // If we detect locally seeded dishes for this version and remote dishes exist, drop the local seeded ones
                            PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: bg)
                            // Merge duplicate dishes and then normalize ingredients
                            PersistenceController.shared.cleanupDuplicateDishes(context: bg)
                            PersistenceController.shared.normalizeDishIngredientDetails(context: bg)
                            // Restore missing categories from preload data (in case keep had nil)
                            PersistenceController.shared.restoreDishCategoriesFromPreload(context: bg)
                            // Re-encode legacy week keys of imported menus, then normalize and deduplicate menus
                            MenuService(context: bg).migrateLegacyWeekKeys()
                            PersistenceController.shared.normalizeMenuMealTypeStrings(context: bg)
                            PersistenceController.shared.cleanupDuplicateMenus(context: bg)
                            DispatchQueue.main.async {
                                // Notify UI layers to refresh after sync
                                NotificationCenter.default.post(name: .appDataDidReconcileAfterCloudKitImport, object: nil)
                                // Before the account status is known, startup will run the check itself
                                if self.isAccountStatusResolved {
                                    self.checkDatabaseState()
                                }
                            }
                        }
                    }
                }
            }
        default:
            break
        }
    }

    private func checkDatabaseState() {
        // Double-check that persistence is ready before proceeding
        guard dataStore.isReady else {
            self.persistenceError = dataStore.userFriendlyErrorMessage
            self.showPersistenceErrorAlert = true
            self.isLoading = false
            return
        }
        
        // If CloudKit is available and the local store is empty, gate seeding conservatively,
        // unless a seeding lease has been acquired which explicitly allows local seeding.
        if AppSeedingGating.shouldGateSeeding(
            isICloudAvailable: isICloudAvailable,
            isCloudKitContainer: dataStore.cloudKitContainerIdentifier != nil,
            isDatabaseEmpty: dataStore.isDatabaseEmpty(),
            hasSeedingLease: hasCloudKitSeedingLease
        ) {
            startSeedingGate()
            return
        }
        // Data arrived by another path (e.g. the import observer) while the gate was still waiting
        cancelSeedingGate()
        
        let needsDataPopulation = dataStore.needsDataPopulation()
        let mirrorsToCloudKit = isICloudAvailable && dataStore.cloudKitContainerIdentifier != nil
        
        if needsDataPopulation && mirrorsToCloudKit && isCloudKitSyncing {
            // Partially imported data: seeding now would race the rest of the import.
            // The import-completed handler re-runs this check.
            AppLogger.info("CloudKit import in progress – waiting for it before populating data", category: AppLogger.cloudKit)
            isLoading = true
            // A held lease is kept: the post-import check must still be allowed to seed
            return
        }
        // The lease allows exactly one seeding attempt: a retry (e.g. after a failure) must gate and reacquire it,
        // since another device may take over the lease once it is stale.
        hasCloudKitSeedingLease = false
        
        // Avoid global cleanup that may over-delete; reconciliation runs after import
        
        // One-time draft migration and cleanup of abandoned drafts
        dataStore.performStartupMaintenance()
        
        if needsDataPopulation {
            // Use background context for initial data generation to avoid blocking UI
            let cloudImportSnapshot = self.isCloudKitSyncing
            let seedGeneration = accountGeneration
            dataStore.generateInitialData(isCloudImportInProgress: cloudImportSnapshot) { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if success && seedGeneration != self.accountGeneration {
                        // The account changed while seeding: the gate and lease were for the previous account, so do not
                        // mark the new one seeded; re-run the database check for the new account instead
                        AppLogger.warning("iCloud account changed during initial data generation – not marking the account seeded", category: AppLogger.cloudKit)
                        self.checkDatabaseState()
                    } else if success {
                        // When seeded successfully in CloudKit environment, mark account seeded.
                        // Generation can be skipped or partially fail and still report success,
                        // so mark only when the store holds the complete current preload data.
                        if mirrorsToCloudKit, self.dataStore.hasCurrentPreloadData() {
                            let service = self.seedingService
                            let version = self.dataStore.preloadDataVersion
                            Task { await service.markAccountSeeded(version: version) }
                        }
                        // Initialize static data cache after database is ready
                        // This will preload all static data to ensure immediate availability
                        self.dataStore.didFinishLoading()
                        self.isLoading = false
                    } else {
                        self.persistenceError = "Failed to initialize app data. Please restart the app.".localized()
                        self.showPersistenceErrorAlert = true
                        self.isLoading = false
                    }
                }
            }
        } else {
            // Initialize static data cache after database is ready
            // This will preload all static data to ensure immediate availability
            dataStore.didFinishLoading()
            isLoading = false
        }
    }

    /// Waits (keeping the loading screen) until CloudKit data arrives or this device may seed locally.
    private func startSeedingGate() {
        guard seedingGateTask == nil else { return }
        AppLogger.info("CloudKit active and local store empty – gating seeding on import or remote emptiness", category: AppLogger.cloudKit)
        isLoading = true
        let service = seedingService
        let version = dataStore.preloadDataVersion
        let maxWait = seedingGateMaxWait
        let retryDelay = seedingGateRetryDelay
        seedingGateTask = Task { [weak self] in
            while !Task.isCancelled {
                let decision = await AppSeedingGating.runGateRound(service: service, version: version, maxWait: maxWait)
                guard !Task.isCancelled, let self else { return }
                switch decision {
                case .recheckDatabase:
                    // Let the import's view-context merge settle before judging the store
                    try? await Task.sleep(nanoseconds: UInt64(Self.cloudKitMergeSettleDelay * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    self.seedingGateTask = nil
                    self.checkDatabaseState()
                    return
                case .seedLocally:
                    self.hasCloudKitSeedingLease = true
                    self.seedingGateTask = nil
                    self.checkDatabaseState()
                    return
                case .keepWaiting:
                    // Imported data may have reached the store without this round seeing the import event
                    if !self.dataStore.isDatabaseEmpty() {
                        AppLogger.info("Local store no longer empty – proceeding without seeding", category: AppLogger.cloudKit)
                        self.seedingGateTask = nil
                        self.checkDatabaseState()
                        return
                    }
                    self.isLoading = true
                }
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
    }

    /// Recovers from NSPersistentCloudKitContainer purging the local mirror. On an iCloud account change
    /// (sign-out, switch, or iCloud turned off for the app) the container deletes the data mirrored from the
    /// old account, so the store can end up empty after startup has already loaded it. Re-resolves the
    /// account status and re-runs the database check: without iCloud this seeds preload data locally,
    /// with a (different) available account it goes through the first-launch seeding gate.
    enum StoreResetTrigger {
        /// `CKAccountChanged`: the account changed, was signed out, or iCloud was turned off for the app
        case accountChanged
        /// A CloudKit setup event finished; the container purges the old account's data during setup
        case setupFinished
        /// The app became active or the store changed remotely; the purge may have happened in between
        case storeChanged
    }

    private func recheckAfterStoreReset(trigger: StoreResetTrigger) {
        let accountChanged = trigger == .accountChanged
        // Before the account status is known, startup runs the check itself (after refreshing the view context)
        guard isAccountStatusResolved else {
            hasStoreResetBeforeStartupCheck = true
            return
        }
        if accountChanged {
            // A running gate round, a held lease and an in-flight seed belong to the previous account
            accountGeneration += 1
            cancelSeedingGate()
            hasCloudKitSeedingLease = false
        } else if storeResetRecheckTask != nil || seedingGateTask != nil {
            // A pending account-change recheck or the running seeding gate already covers this
            return
        }
        storeResetRecheckTask?.cancel()
        storeResetRecheckTask = Task { [weak self] in
            // Let the purge's merge into the view context settle before judging the store
            try? await Task.sleep(nanoseconds: UInt64(Self.cloudKitMergeSettleDelay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.dataStore.isReady else { return }
            // The store is judged from a fresh context (`storeNeedsDataPopulation`): the view context may not have
            // seen the purge, and it is only refreshed once recovery is confirmed, so ordinary activations do not
            // disturb unsaved edits.
            // iCloud may have been turned on for the app (which posts no CKAccountChanged) since mirroring last failed
            let wasICloudUnavailable = !self.isICloudAvailable && self.dataStore.cloudKitContainerIdentifier != nil
            guard accountChanged || wasICloudUnavailable || self.dataStore.storeNeedsDataPopulation() else {
                self.storeResetRecheckTask = nil
                return
            }
            // Seed locally only after an explicit non-available status: on a failed lookup the store is still
            // CloudKit-backed, and ungated preload data could later upload into the new account's data
            while !(await self.resolveICloudAccountStatus(keepAvailabilityOnFailure: true)) {
                guard !Task.isCancelled else { return }
                guard self.dataStore.storeNeedsDataPopulation() else {
                    // Nothing to recover (any more): the next trigger checks the account again
                    self.storeResetRecheckTask = nil
                    self.finishLoadingIfWaiting()
                    return
                }
                AppLogger.warning("iCloud account status unknown after account change or setup – retrying before the database check", category: AppLogger.cloudKit)
                self.isLoading = true
                try? await Task.sleep(nanoseconds: UInt64(max(self.seedingGateRetryDelay, Self.cloudKitMergeSettleDelay) * 1_000_000_000))
                guard !Task.isCancelled else { return }
            }
            guard !Task.isCancelled else { return }
            self.storeResetRecheckTask = nil
            if wasICloudUnavailable && self.isICloudAvailable {
                if self.dataStore.hasUnsavedChanges {
                    self.deferMirroringRestartUntilSaved()
                } else {
                    self.restartCloudKitMirroring()
                }
                return
            }
            guard self.dataStore.storeNeedsDataPopulation() else {
                // Account changed but its data is still here (the purge, if any, triggers another check),
                // or data arrived while an earlier lookup failure kept the loading screen up
                self.finishLoadingIfWaiting()
                return
            }
            // Bring the view context and the static data cache up to date with the store
            self.dataStore.reloadAfterStoreReset()
            if trigger == .storeChanged, self.isICloudAvailable, !self.dataStore.isDatabaseEmpty() {
                // Partly imported data with iCloud on: the import-completed check handles it
                self.finishLoadingIfWaiting()
                return
            }
            AppLogger.warning("Local store was cleared after startup (iCloud account change) – re-running the database check", category: AppLogger.cloudKit)
            // Show the loading screen so the UI rebuilds once the store is populated again
            self.isLoading = true
            self.checkDatabaseState()
        }
    }

    /// Clears a loading screen this recheck put up when the store turned out not to need recovery
    private func finishLoadingIfWaiting() {
        guard isLoading, seedingGateTask == nil else { return }
        checkDatabaseState()
    }

    /// Reloading the store resets the view context, which would drop an edit in progress (dish and product edits
    /// stay unsaved until Save). Keep iCloud counted as unavailable, since mirroring is not running yet, so the
    /// next save or activation checks the account again and restarts mirroring then.
    private func deferMirroringRestartUntilSaved() {
        AppLogger.info("iCloud became available – restarting CloudKit mirroring after unsaved edits are finished", category: AppLogger.cloudKit)
        isICloudAvailable = false
        guard deferredRestartSaveObserver == nil else { return }
        deferredRestartSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let token = self.deferredRestartSaveObserver {
                    NotificationCenter.default.removeObserver(token)
                    self.deferredRestartSaveObserver = nil
                }
                self.recheckAfterStoreReset(trigger: .storeChanged)
            }
        }
    }

    /// iCloud became available while the app runs. Mirroring set up without an account stays off until the store
    /// is reloaded, so reload it behind the loading screen (the UI is rebuilt afterwards), then run the usual
    /// check: an empty store goes through the seeding gate, local data is merged by the import reconciliation.
    private func restartCloudKitMirroring() {
        AppLogger.info("iCloud became available – restarting CloudKit mirroring", category: AppLogger.cloudKit)
        isLoading = true
        dataStore.reloadStoreForCloudKitMirroring { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                guard success else {
                    self.persistenceError = "Failed to initialize app data. Please restart the app.".localized()
                    self.showPersistenceErrorAlert = true
                    self.isLoading = false
                    return
                }
                self.dataStore.reloadAfterStoreReset()
                self.checkDatabaseState()
            }
        }
    }

    #if DEBUG
    /// Runs the database check the import-completed handler runs (an import event cannot be constructed in tests)
    func recheckDatabaseStateForTesting() {
        checkDatabaseState()
    }

    /// Runs what a finished CloudKit setup event triggers (a setup event cannot be constructed in tests)
    func cloudKitSetupDidFinishForTesting() {
        recheckAfterStoreReset(trigger: .setupFinished)
    }
    #endif

    private func cancelSeedingGate() {
        seedingGateTask?.cancel()
        seedingGateTask = nil
    }
    
    /// One-time draft migration followed by cleanup of abandoned drafts, run on every startup
    static func performDraftMaintenance(context: NSManagedObjectContext) {
        // One-time migration: Restore user data that was incorrectly marked as drafts
        restoreUserDataFromDrafts(context: context)
        // Clean up any abandoned draft entities from incomplete creation flows
        cleanupAbandonedDrafts(context: context)
    }

    /// Cleans up abandoned draft entities that were created but never completed
    /// Uses intelligent cleanup strategy to balance safety with database cleanliness
    private static func cleanupAbandonedDrafts(context: NSManagedObjectContext) {
        // Configuration - can be adjusted based on user feedback or made user-configurable
        let maxDraftDishesToKeep = UserDefaults.standard.object(forKey: "MaxDraftDishesToKeep") as? Int ?? 10
        let maxDraftProductsToKeep = UserDefaults.standard.object(forKey: "MaxDraftProductsToKeep") as? Int ?? 5
        AppLogger.info("Cleaning up abandoned draft entities", category: AppLogger.appState)
        
        context.performAndWait {
            var entitiesDeleted = 0
            
            // Clean up draft dishes using tiered approach
            let dishFetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            dishFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftDishes = try context.fetch(dishFetchRequest)
                var actuallyDeleted = 0
                let maxDraftsToKeep = maxDraftDishesToKeep
                
                // Separate dishes into categories
                var emptyDishes: [Dish] = []
                var minimalContentDishes: [Dish] = []
                var substantialContentDishes: [Dish] = []
                
                for dish in draftDishes {
                    let hasName = !(dish.name?.isEmpty ?? true)
                    let hasIngredients = (dish.ingredientDetails?.count ?? 0) > 0
                    let hasMealTypes = (dish.mealTypes?.count ?? 0) > 0
                    let hasCategory = dish.category != nil
                    let hasDetails = !(dish.details?.isEmpty ?? true)
                    
                    if !hasName && !hasIngredients && !hasMealTypes && !hasCategory && !hasDetails {
                        // Completely empty - always safe to delete
                        emptyDishes.append(dish)
                    } else if hasIngredients || hasMealTypes || (hasName && (hasDetails || hasCategory)) {
                        // Has substantial content - preserve
                        substantialContentDishes.append(dish)
                    } else {
                        // Minimal content (e.g., just name) - delete if too many
                        minimalContentDishes.append(dish)
                    }
                }
                
                // Always delete completely empty dishes
                for dish in emptyDishes {
                    context.delete(dish)
                    actuallyDeleted += 1
                }
                
                // Delete excess minimal content dishes (keep most recent ones)
                if minimalContentDishes.count > maxDraftsToKeep {
                    let excessCount = minimalContentDishes.count - maxDraftsToKeep
                    // Sort by object ID to get consistent ordering (older objects typically have lower IDs)
                    let sortedMinimal = minimalContentDishes.sorted { $0.objectID.description < $1.objectID.description }
                    
                    for i in 0..<excessCount {
                        context.delete(sortedMinimal[i])
                        actuallyDeleted += 1
                    }
                }
                
                entitiesDeleted += actuallyDeleted
                AppLogger.info("Found \(draftDishes.count) draft dishes: \(emptyDishes.count) empty, \(minimalContentDishes.count) minimal, \(substantialContentDishes.count) substantial. Deleted \(actuallyDeleted) drafts.", category: AppLogger.appState)
            } catch {
                AppLogger.error("Failed to fetch draft dishes for cleanup", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft dishes for cleanup")
            }
            
            // Clean up draft products using tiered approach
            let productFetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            productFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftProducts = try context.fetch(productFetchRequest)
                var actuallyDeleted = 0
                let maxProductDraftsToKeep = maxDraftProductsToKeep
                
                // Separate products into categories
                var emptyProducts: [Product] = []
                var minimalContentProducts: [Product] = []
                var substantialContentProducts: [Product] = []
                
                for product in draftProducts {
                    let hasName = !(product.name?.isEmpty ?? true)
                    let hasUnit = product.unit != nil
                    let hasIngredientUsage = (product.ingredientDetails?.count ?? 0) > 0
                    
                    if !hasName && !hasUnit {
                        // Completely empty - always safe to delete
                        emptyProducts.append(product)
                    } else if hasUnit && hasName {
                        // Has both name and unit - preserve
                        substantialContentProducts.append(product)
                    } else if hasIngredientUsage {
                        // Already used in dishes - preserve
                        substantialContentProducts.append(product)
                    } else {
                        // Minimal content (just name OR just unit) - delete if too many
                        minimalContentProducts.append(product)
                    }
                }
                
                // Always delete completely empty products
                for product in emptyProducts {
                    context.delete(product)
                    actuallyDeleted += 1
                }
                
                // Delete excess minimal content products
                if minimalContentProducts.count > maxProductDraftsToKeep {
                    let excessCount = minimalContentProducts.count - maxProductDraftsToKeep
                    let sortedMinimal = minimalContentProducts.sorted { $0.objectID.description < $1.objectID.description }
                    
                    for i in 0..<excessCount {
                        context.delete(sortedMinimal[i])
                        actuallyDeleted += 1
                    }
                }
                
                entitiesDeleted += actuallyDeleted
                AppLogger.info("Found \(draftProducts.count) draft products: \(emptyProducts.count) empty, \(minimalContentProducts.count) minimal, \(substantialContentProducts.count) substantial. Deleted \(actuallyDeleted) drafts.", category: AppLogger.appState)
            } catch {
                AppLogger.error("Failed to fetch draft products for cleanup", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft products for cleanup")
            }
            
            // Save changes if any entities were deleted
            if entitiesDeleted > 0 {
                do {
                    try context.save()
                    AppLogger.info("Successfully cleaned up \(entitiesDeleted) truly abandoned draft entities", category: AppLogger.appState)
                } catch {
                    AppLogger.error("Failed to save after cleaning up draft entities", error: error, category: AppLogger.appState)
                    AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to save after cleaning up draft entities")
                }
            } else {
                AppLogger.info("No truly abandoned draft entities found", category: AppLogger.appState)
            }
        }
    }
    
    // MARK: - Draft Cleanup Configuration
    
    /// Updates the maximum number of draft entities to keep during cleanup
    /// - Parameters:
    ///   - maxDishes: Maximum draft dishes to preserve (default: 10)
    ///   - maxProducts: Maximum draft products to preserve (default: 5)
    static func configureDraftCleanupLimits(maxDishes: Int = 10, maxProducts: Int = 5) {
        UserDefaults.standard.set(maxDishes, forKey: "MaxDraftDishesToKeep")
        UserDefaults.standard.set(maxProducts, forKey: "MaxDraftProductsToKeep")
        UserDefaults.standard.synchronize()
        AppLogger.info("Updated draft cleanup limits: dishes=\(maxDishes), products=\(maxProducts)", category: AppLogger.appState)
    }
    
    /// Gets current draft cleanup configuration
    static func getDraftCleanupLimits() -> (dishes: Int, products: Int) {
        let dishes = UserDefaults.standard.object(forKey: "MaxDraftDishesToKeep") as? Int ?? 10
        let products = UserDefaults.standard.object(forKey: "MaxDraftProductsToKeep") as? Int ?? 5
        return (dishes: dishes, products: products)
    }
    
    /// One-time migration: Restores user data that was incorrectly marked as drafts
    /// This fixes the issue where existing entities were marked as drafts during the initial implementation
    private static func restoreUserDataFromDrafts(context: NSManagedObjectContext) {
        // Check if this migration has already been performed
        let migrationKey = "DraftMigrationCompleted_v1"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            AppLogger.info("Draft migration already completed, skipping", category: AppLogger.appState)
            return
        }
        
        AppLogger.info("Performing one-time migration to restore user data from incorrect draft status", category: AppLogger.appState)
        
        context.performAndWait {
            var entitiesRestored = 0
            
            // Restore dishes that have meaningful content
            let dishFetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
            dishFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftDishes = try context.fetch(dishFetchRequest)
                for dish in draftDishes {
                    // If dish has a name and either ingredients or meal types, it's likely user data
                    let hasName = !(dish.name?.isEmpty ?? true)
                    let hasIngredients = (dish.ingredientDetails?.count ?? 0) > 0
                    let hasMealTypes = (dish.mealTypes?.count ?? 0) > 0
                    
                    if hasName && (hasIngredients || hasMealTypes) {
                        dish.isDraft = false
                        entitiesRestored += 1
                        AppLogger.info("Restored dish: \(dish.name ?? "unnamed")", category: AppLogger.appState)
                    }
                }
            } catch {
                AppLogger.error("Failed to fetch draft dishes for migration", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft dishes for migration")
            }
            
            // Restore products that have meaningful content
            let productFetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            productFetchRequest.predicate = NSPredicate(format: "isDraft == YES")
            
            do {
                let draftProducts = try context.fetch(productFetchRequest)
                for product in draftProducts {
                    // If product has a name and unit, it's likely user data
                    let hasName = !(product.name?.isEmpty ?? true)
                    let hasUnit = product.unit != nil
                    
                    if hasName && hasUnit {
                        product.isDraft = false
                        entitiesRestored += 1
                        AppLogger.info("Restored product: \(product.name ?? "unnamed")", category: AppLogger.appState)
                    }
                }
            } catch {
                AppLogger.error("Failed to fetch draft products for migration", error: error, category: AppLogger.appState)
                AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to fetch draft products for migration")
            }
            
            // Save changes if any entities were restored
            if entitiesRestored > 0 {
                do {
                    try context.save()
                    AppLogger.info("Successfully restored \(entitiesRestored) user entities from incorrect draft status", category: AppLogger.appState)
                } catch {
                    AppLogger.error("Failed to save after restoring entities from draft status", error: error, category: AppLogger.appState)
                    AnalyticsManager.shared.trackError(error, domain: "iCloud", category: "Failed to save after restoring entities from draft status")
                    return
                }
            } else {
                AppLogger.info("No user entities found to restore from draft status", category: AppLogger.appState)
            }
            
            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationKey)
            UserDefaults.standard.synchronize()
            AppLogger.info("Draft migration completed successfully", category: AppLogger.appState)
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let appDataDidReconcileAfterCloudKitImport = Notification.Name("AppDataDidReconcileAfterCloudKitImport")
}

// MARK: - Testable helpers
enum AppSeedingGating {
    /// Determines whether the app should gate initial data seeding awaiting CloudKit signals.
    /// Returns true when CloudKit is available, a CloudKit container is in use, and the database is empty,
    /// and no seeding lease has been acquired.
    static func shouldGateSeeding(isICloudAvailable: Bool,
                                  isCloudKitContainer: Bool,
                                  isDatabaseEmpty: Bool,
                                  hasSeedingLease: Bool) -> Bool {
        if hasSeedingLease { return false }
        return isICloudAvailable && isCloudKitContainer && isDatabaseEmpty
    }

    enum GateDecision: Equatable {
        /// CloudKit delivered data (or may have): re-run the database check
        case recheckDatabase
        /// Remote is empty and this device holds the seeding lease
        case seedLocally
        /// No decision yet: keep the loading screen and run another round
        case keepWaiting
    }

    /// One round of the first-launch seeding gate. Never allows local seeding unless the remote mirror
    /// is confirmed empty, the seed marker is confirmed absent (or for another version), and the seeding lease was acquired.
    @MainActor
    static func runGateRound(service: CloudKitSeedingService, version: String, maxWait: TimeInterval) async -> GateDecision {
        let markerStatus = await service.isAccountSeeded(version: version)
        let outcome = await service.waitForImportOrRemoteEmpty(maxWait: maxWait)
        switch outcome {
        case .importCompleted:
            AppLogger.info("CloudKit import completed – proceeding", category: AppLogger.cloudKit)
            return .recheckDatabase
        case .timedOut:
            AppLogger.info("CloudKit gating timed out – continue waiting without seeding", category: AppLogger.cloudKit)
            return .keepWaiting
        case .remoteAppearsEmpty:
            switch markerStatus {
            case .seeded:
                // Another device seeded this version but has not exported its records yet
                AppLogger.info("Account already seeded but remote mirror still empty – waiting for import", category: AppLogger.cloudKit)
                return .keepWaiting
            case .unknown:
                AppLogger.info("Account seed marker unreadable – waiting instead of seeding", category: AppLogger.cloudKit)
                return .keepWaiting
            case .notSeeded:
                break
            }
            // Acquire a seeding lease to prevent multiple devices seeding simultaneously
            if await service.tryAcquireSeedingLease() {
                AppLogger.info("Seeding lease acquired – allowing local seed", category: AppLogger.cloudKit)
                return .seedLocally
            }
            AppLogger.info("Seeding lease not acquired – waiting for remote import", category: AppLogger.cloudKit)
            return .keepWaiting
        }
    }
}

/// How `AppStateManager` starts, derived from the process environment
enum StartupMode: Equatable {
    /// Unit tests / CI: no startup work at all
    case skipped
    /// UI tests or CloudKit disabled (launch argument or environment): local store only, no iCloud account check
    case localOnly
    /// Normal launch: resolve the iCloud account status before deciding on seeding
    case cloudKitAware

    static func detect(environment: [String: String] = ProcessInfo.processInfo.environment,
                       arguments: [String] = ProcessInfo.processInfo.arguments,
                       isXCTestLoaded: Bool = NSClassFromString("XCTestCase") != nil) -> StartupMode {
        if environment["GITHUB_ACTIONS"] != nil ||
            environment["CI"] != nil ||
            environment["BUILD_NUMBER"] != nil ||
            environment["XCTestConfigurationFilePath"] != nil {
            return .skipped
        }
        if arguments.contains("-UITests") ||
            arguments.contains("-DisableCloudKit") ||
            environment["UI_TESTS"] != nil ||
            environment["DISABLE_CLOUDKIT"] != nil ||
            isXCTestLoaded {
            return .localOnly
        }
        return .cloudKitAware
    }
}

/// Store operations `AppStateManager` needs during startup. Live implementation: `PersistenceStartupDataStore`.
@MainActor
protocol StartupDataStore {
    var isReady: Bool { get }
    var userFriendlyErrorMessage: String? { get }
    /// CloudKit container the store mirrors to, or nil when CloudKit mirroring is off (tests, simulator)
    var cloudKitContainerIdentifier: String? { get }
    var preloadDataVersion: String { get }
    func isDatabaseEmpty() -> Bool
    func needsDataPopulation() -> Bool
    /// `needsDataPopulation()` judged from a fresh context, without touching the view context
    func storeNeedsDataPopulation() -> Bool
    /// Whether the view context holds unsaved edits (e.g. an open dish or product editor)
    var hasUnsavedChanges: Bool { get }
    /// True when the store holds the complete preload data of the current version
    func hasCurrentPreloadData() -> Bool
    func performStartupMaintenance()
    func generateInitialData(isCloudImportInProgress: Bool, completion: @escaping (Bool) -> Void)
    /// Called once the store has data and the UI can load
    func didFinishLoading()
    /// Brings the view context and caches up to date with the store, which may have been cleared behind
    /// the app's back (CloudKit account-change purge)
    func reloadAfterStoreReset()
    /// Reloads the store so CloudKit mirroring is set up again (after iCloud became available)
    func reloadStoreForCloudKitMirroring(completion: @escaping (Bool) -> Void)
    func attemptRecovery(completion: @escaping (Bool) -> Void)
}

@MainActor
struct PersistenceStartupDataStore: StartupDataStore {
    private var persistence: PersistenceController { PersistenceController.shared }
    private var viewContext: NSManagedObjectContext { persistence.container.viewContext }

    var isReady: Bool { persistence.isReady }
    var userFriendlyErrorMessage: String? { persistence.userFriendlyErrorMessage }
    var cloudKitContainerIdentifier: String? {
        guard persistence.container is NSPersistentCloudKitContainer else { return nil }
        return persistence.container.persistentStoreDescriptions.first?.cloudKitContainerOptions?.containerIdentifier
    }
    var preloadDataVersion: String { persistence.getCurrentPreloadDataVersion() }

    func isDatabaseEmpty() -> Bool { persistence.isDatabaseEmpty(context: viewContext) }
    func needsDataPopulation() -> Bool { persistence.isDatabaseEmptyOrOutdated(context: viewContext) }
    var hasUnsavedChanges: Bool { viewContext.hasChanges }
    func storeNeedsDataPopulation() -> Bool {
        let context = persistence.newBackgroundContext()
        var needsPopulation = false
        context.performAndWait {
            needsPopulation = persistence.isDatabaseEmptyOrOutdated(context: context)
        }
        return needsPopulation
    }
    func hasCurrentPreloadData() -> Bool {
        !persistence.isDatabaseEmpty(context: viewContext) && persistence.isStaticDataValid(context: viewContext)
    }
    func performStartupMaintenance() { AppStateManager.performDraftMaintenance(context: viewContext) }

    func generateInitialData(isCloudImportInProgress: Bool, completion: @escaping (Bool) -> Void) {
        persistence.generateInitialDataInBackground(isCloudImportInProgress: isCloudImportInProgress, completion: completion)
    }

    func didFinishLoading() { StaticDataCacheManager.shared.initialize(with: viewContext) }
    func reloadAfterStoreReset() {
        // Synchronous (unlike `refreshAfterRemoteMerge`): the caller checks the store right after
        let context = viewContext
        context.performAndWait {
            do { try context.setQueryGenerationFrom(.current) } catch {
                AppLogger.warning("Failed to advance query generation after store reset: \(error.localizedDescription)", category: AppLogger.persistence)
            }
            context.refreshAllObjects()
        }
        StaticDataCacheManager.shared.invalidateCache()
    }

    func reloadStoreForCloudKitMirroring(completion: @escaping (Bool) -> Void) {
        persistence.reloadStoreForCloudKitMirroring(completion: completion)
    }

    func attemptRecovery(completion: @escaping (Bool) -> Void) {
        persistence.attemptRecovery(completion: completion)
    }
}
