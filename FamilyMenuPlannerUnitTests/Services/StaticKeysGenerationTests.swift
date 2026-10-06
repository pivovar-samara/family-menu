//
//  StaticKeysGenerationTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by AI on 01.09.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

final class StaticKeysGenerationFromInitialDataTests: XCTestCase {
    func testIngredientNormalizationRemovesDuplicatesKeepsMaxQuantity() throws {
        let stack = TestCoreDataStack.shared
        let ctx = stack.viewContext
        let factory = TestDataFactory(context: ctx)

        let unit = factory.createUnit(name: "kg")
        let product = factory.createProduct(name: "Apple", unit: unit)
        let dish = factory.createDish(name: "Fruit Salad")

        // Two duplicate details pointing to same product
        let d1 = factory.createIngredientDetail(dish: dish, product: product, quantity: 1.0, unit: unit)
        d1.sortOrder = 2
        let d2 = factory.createIngredientDetail(dish: dish, product: product, quantity: 3.5, unit: unit)
        d2.sortOrder = 1

        PersistenceController.shared.normalizeDishIngredientDetails(context: ctx)

        let fetch: NSFetchRequest<IngredientDetail> = IngredientDetail.fetchRequest()
        let details = try ctx.fetch(fetch)
        XCTAssertEqual(details.count, 1)
        XCTAssertEqual(details.first?.quantity, 3.5)
        XCTAssertEqual(details.first?.sortOrder, 1)
    }

    func testMenuDedupMergesDishes() throws {
        let stack = TestCoreDataStack.shared
        let ctx = stack.viewContext
        let factory = TestDataFactory(context: ctx)

        let breakfast = factory.createMealType(name: "Breakfast")
        let dishA = factory.createDish(name: "Omelette", mealTypes: [breakfast])
        let dishB = factory.createDish(name: "Pancakes", mealTypes: [breakfast])

        // Same logical menu slot duplicated
        let weekDate = Date()
        let encodedWeek = CalendarHelper.weekKey(for: weekDate)

        let m1 = Menu(context: ctx)
        m1.day = "Monday"
        m1.mealType = breakfast.name
        m1.calendarWeek = Int32(encodedWeek)
        m1.addToDishes(dishA)

        let m2 = Menu(context: ctx)
        m2.day = "Monday"
        m2.mealType = breakfast.name
        m2.calendarWeek = Int32(encodedWeek)
        m2.addToDishes(dishB)

        try ctx.save()

        PersistenceController.shared.cleanupDuplicateMenus(context: ctx)

        let fetch: NSFetchRequest<Menu> = Menu.fetchRequest()
        let menus = try ctx.fetch(fetch)
        XCTAssertEqual(menus.count, 1)
        let dishes = (menus.first?.dishes?.allObjects as? [Dish]) ?? []
        let names = Set(dishes.compactMap { $0.name })
        XCTAssertEqual(names, Set(["Omelette", "Pancakes"]))
    }
}

// MARK: - Pure unit tests for StaticKeyHelper
final class StaticKeyHelperUnitTests: XCTestCase {
    func testStableKeyGeneration() {
        XCTAssertEqual(StaticKeyHelper.stableKey(from: "  Café au Lait  "), "cafe-au-lait")
        XCTAssertEqual(StaticKeyHelper.stableKey(from: "Sugar--Free"), "sugar-free")
        XCTAssertEqual(StaticKeyHelper.stableKey(from: "Молоко"), StaticKeyHelper.stableKey(from: "молоко"))
        XCTAssertEqual(StaticKeyHelper.stableKey(from: "Milk!"), "milk")
    }
    
    func testProductKeyComposition() {
        XCTAssertEqual(StaticKeyHelper.productKey(name: "Milk", unitKey: "l"), "milk|l")
        XCTAssertEqual(StaticKeyHelper.productKey(name: "Milk", unitKey: nil), "milk")
        XCTAssertEqual(StaticKeyHelper.productKey(name: "Milk", unitKey: ""), "milk")
    }
}

