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
                ProgressView("Loading...")
            }
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
                    ManageDishesView()
                        .navigationTitle("Dishes")
                }
                .tabItem {
                    Label("Dishes", systemImage: "fork.knife")
                }
            }
        }
    }
}
