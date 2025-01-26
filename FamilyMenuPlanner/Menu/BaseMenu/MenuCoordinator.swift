//
//  MenuCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 14.01.25.
//

import SwiftUI

class MenuCoordinator {
    func createMenuView() -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = MenuService(context: context)
        let viewModel = MenuViewModel(menuService: service)
        return MenuView(viewModel: viewModel)
    }
}
