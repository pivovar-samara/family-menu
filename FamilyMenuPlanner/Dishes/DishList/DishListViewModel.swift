//
//  DishListViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import Foundation
import SwiftUI
import Combine

class DishListViewModel: ObservableObject {
    @Published var selectedDish: Dish? = nil // For editing
    @Published var isAddingNewDish: Bool = false
    @Published var currentAlert: AlertItem? = nil
    @Published var dishes: [Dish] = []
    
    private var dishListService: DishListServiceProtocol
    private let alertManager = AlertQueueManager()

    init(dishListService: DishListServiceProtocol) {
        self.dishListService = dishListService
        self.dishListService.delegate = self
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
    }
    
    func loadDishes() {
        dishListService.fetchAllDishes()
    }
    
    func deleteDishes(at offsets: IndexSet) {
        do {
            var dishesToDelete: [Dish] = []
            for index in offsets {
                let dish = dishes[index]
                dishesToDelete.append(dish)
            }
            dishes.remove(atOffsets: offsets)
            try dishListService.deleteDishes(dishes: dishesToDelete)
        } catch {
            enqueueAlert(title: "Error", message: "Failed to delete dishes. Please try again.")
        }
    }

    func enqueueAlert(title: String, message: String, action: (() -> Void)? = nil) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: action)
        alertManager.enqueue(alert: alert)
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }
}

extension DishListViewModel: DishListServiceDelegate {
    func serviceDidChangeContent(_ dishes: [Dish]) {
        self.dishes = dishes
    }
}
