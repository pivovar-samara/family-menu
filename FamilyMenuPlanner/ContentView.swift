//
//  ContentView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView {
            // Menu
            NavigationStack {
                MenuView()
                    .navigationTitle("Menu")
            }
            .tabItem {
                Label("Menu", systemImage: "calendar")
            }

            // Products
            NavigationStack {
                ProductListView()
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
