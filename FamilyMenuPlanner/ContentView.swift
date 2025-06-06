//
//  ContentView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var appStateManager = AppStateManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        if appStateManager.isLoading {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView("Loading...".localized())
                    
                    // Check readiness from the environment context instead of hardcoded shared
                    if viewContext.persistentStoreCoordinator?.persistentStores.isEmpty != false {
                        Text("Setting up your data...".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else if appStateManager.showPersistenceErrorAlert {
            // Show error state with recovery options
            ErrorRecoveryView()
        } else {
            TabView {
                // Menu
                NavigationStack {
                    MenuCoordinator().createMenuView()
                        .navigationTitle("Menu")
                }
                .tabItem {
                    Label("Menu", systemImage: "calendar")
                }

                // Products
                NavigationStack {
                    ProductListCoordinator().createProductListView()
                        .navigationTitle("Products")
                }
                .tabItem {
                    Label("Products", systemImage: "list.bullet")
                }

                // Dishes
                NavigationStack {
                    DishListCoordinator().createDishListView()
                        .navigationTitle("Dishes")
                }
                .tabItem {
                    Label("Dishes", systemImage: "fork.knife")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

struct ErrorRecoveryView: View {
    @StateObject private var appStateManager = AppStateManager.shared

    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("App Initialization Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let errorMessage = appStateManager.persistenceError {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Button("Try Again") {
                    appStateManager.retryPersistenceSetup()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .padding()
        }
    }
}
