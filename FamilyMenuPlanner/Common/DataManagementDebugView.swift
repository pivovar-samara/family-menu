//
//  DataManagementDebugView.swift
//  FamilyMenuPlanner
//
//  Created by AI Assistant on 21.01.25.
//

import SwiftUI
import CoreData

/// Debug view for testing and managing data population
/// Only available in DEBUG builds
struct DataManagementDebugView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var currentAlert: AlertData?
    
    var body: some View {
        List {
            // Data Version Info Section
            Section {
                HStack {
                    Text("Current Version:")
                    Spacer()
                    Text(PersistenceController.shared.getCurrentPreloadDataVersion())
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color("SecondaryBackgroundColor"))
                
                HStack {
                    Text("Stored Version:")
                    Spacer()
                    Text(PersistenceController.shared.getStoredPreloadDataVersion() ?? "None")
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color("SecondaryBackgroundColor"))
                
                HStack {
                    Text("Database Status:")
                    Spacer()
                    Text(getDatabaseStatus())
                        .foregroundColor(getDatabaseStatusColor())
                        .fontWeight(.medium)
                }
                .listRowBackground(Color("SecondaryBackgroundColor"))
            } header: {
                Text("Data Version Info")
            }
            
            // Database Operations Section
            Section {
                Button("Check Data Validity") {
                    checkDataValidity()
                }
                .foregroundColor(Color("AccentColor"))
                .listRowBackground(Color("SecondaryBackgroundColor"))
                
                Button("Force Schema Update") {
                    forceSchemaUpdate()
                }
                .foregroundColor(.orange)
                .listRowBackground(Color("SecondaryBackgroundColor"))
                
                Button("Clear All Data") {
                    clearAllData()
                }
                .foregroundColor(.red)
                .listRowBackground(Color("SecondaryBackgroundColor"))
                
                Button("Regenerate Initial Data") {
                    regenerateInitialData()
                }
                .foregroundColor(.blue)
                .listRowBackground(Color("SecondaryBackgroundColor"))
            } header: {
                Text("Database Operations")
            }
            
            // Cache Management Section
            Section {
                Button("Invalidate Static Cache") {
                    invalidateStaticCache()
                }
                .foregroundColor(Color("AccentColor"))
                .listRowBackground(Color("SecondaryBackgroundColor"))
                
                Button("Show Cache Status") {
                    showCacheStatus()
                }
                .foregroundColor(Color("AccentColor"))
                .listRowBackground(Color("SecondaryBackgroundColor"))
            } header: {
                Text("Cache Management")
            }
        }
        .applyStyle()
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.large)
        .alert(item: Binding(
            get: { currentAlert },
            set: { _ in dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    alert.action?()
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDatabaseStatus() -> String {
        let persistence = PersistenceController.shared
        if persistence.isDatabaseEmpty(context: viewContext) {
            return "Empty"
        } else if persistence.isDatabaseEmptyOrOutdated(context: viewContext) {
            return "Outdated"
        } else {
            return "Valid"
        }
    }
    
    private func getDatabaseStatusColor() -> Color {
        let persistence = PersistenceController.shared
        if persistence.isDatabaseEmpty(context: viewContext) {
            return .red
        } else if persistence.isDatabaseEmptyOrOutdated(context: viewContext) {
            return .orange
        } else {
            return .green
        }
    }
    
    // MARK: - Action Methods
    
    private func checkDataValidity() {
        let persistence = PersistenceController.shared
        let isEmpty = persistence.isDatabaseEmpty(context: viewContext)
        let isOutdated = persistence.isDatabaseEmptyOrOutdated(context: viewContext)
        
        if isEmpty {
            showAlert(title: "Database Status", message: "Database is empty. Initial data population needed.")
        } else if isOutdated {
            showAlert(title: "Database Status", message: "Database contains outdated schema. Re-population recommended.")
        } else {
            showAlert(title: "Database Status", message: "Database is valid and up-to-date.")
        }
    }
    
    private func forceSchemaUpdate() {
        PersistenceController.shared.forceDataSchemaUpdate(context: viewContext)
        showAlert(title: "Schema Update", message: "Schema update completed. Static data has been refreshed.")
    }
    
    private func clearAllData() {
        PersistenceController.shared.deleteAllDataInBackground { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.showAlert(title: "Clear Data", message: "All data has been cleared from the database.")
                case .failure(let error):
                    self.showAlert(title: "Clear Data Error", message: "Failed to clear data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func regenerateInitialData() {
        PersistenceController.shared.generateInitialData(context: viewContext)
        showAlert(title: "Data Generation", message: "Initial data has been regenerated.")
    }
    
    private func invalidateStaticCache() {
        StaticDataCacheManager.shared.invalidateCache {
            DispatchQueue.main.async {
                self.showAlert(title: "Cache Management", message: "Static data cache has been invalidated and refreshed.")
            }
        }
    }
    
    private func showCacheStatus() {
        let units = StaticDataCacheManager.shared.getUnits()
        let mealTypes = StaticDataCacheManager.shared.getMealTypes()
        let categories = StaticDataCacheManager.shared.getDishCategories()
        
        let message = """
        Cache Status:
        Units: \(units.count) items
        Meal Types: \(mealTypes.count) items
        Dish Categories: \(categories.count) items
        """
        
        showAlert(title: "Cache Status", message: message)
    }
    
    // MARK: - Alert Management
    
    private func showAlert(title: String, message: String, action: (() -> Void)? = nil) {
        currentAlert = AlertData(
            title: title,
            message: message,
            action: action
        )
    }
    
    private func dismissAlert() {
        currentAlert = nil
    }
}

// MARK: - Alert Data Model

private struct AlertData: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let action: (() -> Void)?
}

// MARK: - Preview

#if DEBUG
struct DataManagementDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DataManagementDebugView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
#endif
