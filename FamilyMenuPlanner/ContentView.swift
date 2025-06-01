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
    let persistenceController = PersistenceController.shared
    
    var body: some View {
        if appStateManager.isLoading {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView("Loading...".localized())
                    
                    if !persistenceController.isReady {
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

struct ErrorRecoveryView: View {
    @StateObject private var appStateManager = AppStateManager.shared
    @State private var isRetrying = false
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                VStack(spacing: 12) {
                    Text("Data Loading Error".localized())
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(appStateManager.persistenceError ?? "An unexpected error occurred while loading your data.".localized())
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        isRetrying = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            appStateManager.retryPersistenceSetup()
                            isRetrying = false
                        }
                    }) {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRetrying ? "Retrying...".localized() : "Try Again".localized())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRetrying)
                    
                    Button(action: {
                        // Force quit the app - user can restart manually
                        exit(0)
                    }) {
                        Text("Restart App".localized())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 32)
                
                VStack(spacing: 8) {
                    Text("What you can try:".localized())
                        .font(.headline)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HelpText(icon: "iphone", text: "Restart the app".localized())
                        HelpText(icon: "wifi", text: "Check your internet connection".localized())
                        HelpText(icon: "icloud", text: "Verify iCloud is enabled".localized())
                        HelpText(icon: "externaldrive", text: "Ensure sufficient storage space".localized())
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }
}

struct HelpText: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
