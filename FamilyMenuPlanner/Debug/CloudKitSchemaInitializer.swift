//
//  CloudKitSchemaInitializer.swift
//  FamilyMenuPlanner
//

#if DEBUG
import CoreData
import Foundation

/// Pushes the full Core Data schema to the CloudKit Development environment so it can be deployed to Production.
///
/// Development only creates a field when a record with a non-nil value for it is saved, so optional attributes that
/// are always nil and the `*_ckAsset` / `CD_moveReceipt` fields NSPersistentCloudKitContainer relies on never get
/// created from normal use. `initializeCloudKitSchema()` uploads sample records with every attribute set and then
/// deletes them. It runs against a throwaway store, so user data is not touched.
///
/// Enable the `-initCloudKitSchema` launch argument in the scheme, run once signed in to iCloud, then disable it and
/// deploy the schema in CloudKit Console (Development → Schema → Deploy Schema Changes).
enum CloudKitSchemaInitializer {
    static let launchArgument = "-initCloudKitSchema"

    /// Runs synchronously; call before the app's CloudKit container is created.
    static func runIfRequested() {
        let processInfo = ProcessInfo.processInfo
        guard processInfo.arguments.contains(launchArgument) else { return }

        // Test runs inherit the scheme's launch arguments, and the unit test host runs the app's init.
        let isRunningTests = processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                             NSClassFromString("XCTestCase") != nil ||
                             processInfo.environment["UI_TESTS"] != nil ||
                             processInfo.arguments.contains("-UITests") ||
                             processInfo.arguments.contains("-DisableCloudKit")
        guard !isRunningTests else {
            AppLogger.info("Skipping CloudKit schema initialization under tests", category: AppLogger.cloudKit)
            return
        }

        AppLogger.info("Initializing CloudKit schema in \(CloudKitSeedingGate.containerIdentifier)", category: AppLogger.cloudKit)

        // `return` inside the pool only leaves the closure, so success is reported through its result.
        let succeeded: Bool = autoreleasepool {
            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("CloudKitSchemaInit-\(UUID().uuidString)", isDirectory: true)
            defer {
                try? FileManager.default.removeItem(at: tempDirectory)
            }

            do {
                try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            } catch {
                AppLogger.error("Failed to create temporary directory for CloudKit schema initialization", error: error, category: AppLogger.cloudKit)
                return false
            }

            // Same model bundle (FamilyMenuPlanner.momd) PersistenceController loads.
            let container = NSPersistentCloudKitContainer(name: "FamilyMenuPlanner")
            let storeDescription = NSPersistentStoreDescription(url: tempDirectory.appendingPathComponent("SchemaInit.sqlite"))
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: CloudKitSeedingGate.containerIdentifier)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            storeDescription.shouldAddStoreAsynchronously = false
            container.persistentStoreDescriptions = [storeDescription]

            var loadError: Error?
            container.loadPersistentStores { _, error in
                loadError = error
            }
            if let loadError {
                AppLogger.error("Failed to load temporary store for CloudKit schema initialization", error: loadError, category: AppLogger.cloudKit)
                return false
            }

            defer {
                let coordinator = container.persistentStoreCoordinator
                for store in coordinator.persistentStores {
                    do {
                        try coordinator.remove(store)
                    } catch {
                        AppLogger.error("Failed to remove temporary CloudKit schema store", error: error, category: AppLogger.cloudKit)
                    }
                }
            }

            do {
                try container.initializeCloudKitSchema(options: [])
                return true
            } catch {
                AppLogger.error("CloudKit schema initialization failed", error: error, category: AppLogger.cloudKit)
                return false
            }
        }

        if succeeded {
            AppLogger.info("CloudKit schema initialized in Development; deploy it to Production in CloudKit Console", category: AppLogger.cloudKit)
        }
    }
}
#endif
