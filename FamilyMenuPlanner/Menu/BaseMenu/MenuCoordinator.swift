//
//  MenuCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 14.01.25.
//

import SwiftUI

class MenuCoordinator {
    /// Called from `ContentView.body` on every render; the service and view model are only built once `MenuView` needs them.
    func createMenuView(menuService: @autoclosure @escaping () -> MenuServiceProtocol = MenuService(context: PersistenceController.shared.container.viewContext)) -> some View {
        MenuView(viewModel: MenuViewModel(menuService: menuService()))
    }
}
