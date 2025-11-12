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
                Color.appBackground
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
                .trackScreenAppear(name: AnalyticsScreenName.PersistenceError, properties: [AnalyticsPropertyKey.error_message: AppStateManager.shared.persistenceError ?? ""])
        } else {
            ZStack(alignment: .top) {
                TabView {
                    // Menu
                    NavigationStack {
                        MenuCoordinator().createMenuView()
                            .navigationTitle("Menu".localized())
                    }
                    .tabItem {
                        Label("Menu".localized(), systemImage: "calendar")
                            .accessibilityIdentifier("tab_menu")
                    }

                    // Products
                    NavigationStack {
                        ProductListCoordinator().createProductListView()
                            .navigationTitle("Products".localized())
                    }
                    .tabItem {
                        Label("Products".localized(), systemImage: "list.bullet")
                            .accessibilityIdentifier("tab_products")
                    }

                    // Dishes
                    NavigationStack {
                        DishListCoordinator().createDishListView()
                            .navigationTitle("Dishes".localized())
                    }
                    .tabItem {
                        Label("Dishes".localized(), systemImage: "fork.knife")
                            .accessibilityIdentifier("tab_dishes")
                    }
                    
                    #if DEBUG
                    NavigationStack {
                        DataManagementDebugView()
                    }
                    .tabItem {
                        Label("Debug", systemImage: "wrench.and.screwdriver")
                    }
                    #endif
                }
                .accessibilityIdentifier("main_tab_bar")
                
                if appStateManager.isCloudKitSyncing {
                    SyncBannerView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                        .onAppear {
                            AnalyticsManager.shared.track(name: AnalyticsEventName.icloud_banner_appeared)
                        }
                        .onDisappear {
                            AnalyticsManager.shared.track(name: AnalyticsEventName.icloud_banner_disappeared)
                        }
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
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(Color.appWarning)
                
                Text("App Initialization Error".localized())
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let errorMessage = appStateManager.persistenceError {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Button("Try Again".localized()) {
                    appStateManager.retryPersistenceSetup()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
                .padding(.top)
            }
            .padding()
        }
    }
}

