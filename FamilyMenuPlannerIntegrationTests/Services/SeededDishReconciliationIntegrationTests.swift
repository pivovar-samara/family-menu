import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// After an iCloud reconnect the store can hold a seed copy of a preload dish and an imported record with the
/// same key. Only an exact copy of the preload dish may be deleted; a record with edits must survive.
final class SeededDishReconciliationIntegrationTests: BaseIntegrationTest {
    private var preloadDish: DishData!
    private var preloadUnitByProduct: [String: String] = [:]
    private var units: [String: Unit] = [:]
    private var products: [String: Product] = [:]
    private var mealTypes: [String: MealType] = [:]
    private var categories: [String: DishCategory] = [:]

    override func setUp() {
        super.setUp()
        // Runs after the base setUp, which creates the context and fixture factory
        guard let url = Bundle.main.url(forResource: "preloadData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let preload = try? JSONDecoder().decode(PreloadedData.self, from: data) else {
            XCTFail("Cannot load preloadData.json")
            return
        }
        preloadDish = preload.dishes.first {
            !$0.ingredients.isEmpty && $0.category != nil && ($0.mealTypes?.isEmpty == false)
        }
        XCTAssertNotNil(preloadDish, "Preload data needs a dish with ingredients, a category and meal types")
        for product in preload.products {
            preloadUnitByProduct[product.name] = product.unit
        }
    }

    override func tearDown() {
        preloadDish = nil
        preloadUnitByProduct = [:]
        units = [:]
        products = [:]
        mealTypes = [:]
        categories = [:]
        super.tearDown()
    }

    private func unit(_ name: String) -> Unit {
        if let existing = units[name] { return existing }
        let created = createUnit(name: name)
        units[name] = created
        return created
    }

    private func mealType(_ name: String) -> MealType {
        if let existing = mealTypes[name] { return existing }
        let created = createMealType(name: name)
        mealTypes[name] = created
        return created
    }

    /// A dish identical to the preload dish (what seeding creates)
    private func makeSeedCopy() throws -> Dish {
        let dish = createDish(name: preloadDish.name, details: preloadDish.details)
        dish.key = "preload-key"
        if let categoryName = preloadDish.category {
            let category = categories[categoryName] ?? createDishCategory(name: categoryName)
            categories[categoryName] = category
            dish.category = category
        }
        for name in preloadDish.mealTypes ?? [] {
            dish.addToMealTypes(mealType(name))
        }
        for ingredientData in preloadDish.ingredients {
            let product = products[ingredientData.product]
                ?? createProduct(name: ingredientData.product, unit: unit(preloadUnitByProduct[ingredientData.product] ?? ""))
            products[ingredientData.product] = product
            let ingredient = IngredientDetail(context: context)
            ingredient.dish = dish
            ingredient.product = product
            ingredient.quantity = ingredientData.quantity
        }
        try context.save()
        return dish
    }

    private func menuLinking(_ dish: Dish) -> Menu {
        testDataFactory.createMenu(weekStartDate: Date(), dish: dish, mealType: mealType("Menu slot"))
    }

    func testEditedDetailsWinOverMenuLinkedSeedCopy() throws {
        let seed = try makeSeedCopy()
        let menu = menuLinking(seed)
        let imported = try makeSeedCopy()
        imported.details = "Edited by the user"
        try context.save()

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.details, "Edited by the user")
        XCTAssertTrue(menu.dishes?.contains(imported) ?? false)
    }

    func testRelationshipOnlyEditWinsOverMenuLinkedSeedCopy() throws {
        let seed = try makeSeedCopy()
        let menu = menuLinking(seed)
        // Same details and ingredients, but the user changed the meal types and category
        let imported = try makeSeedCopy()
        imported.mealTypes = NSSet(object: mealType("Edited meal type"))
        imported.category = createDishCategory(name: "Edited category")
        try context.save()

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.category?.name, "Edited category")
        XCTAssertTrue(menu.dishes?.contains(imported) ?? false)
    }

    func testCaseOnlyDetailsEditWinsOverMenuLinkedSeedCopy() throws {
        let seed = try makeSeedCopy()
        let menu = menuLinking(seed)
        let imported = try makeSeedCopy()
        imported.details = preloadDish.details.uppercased()
        try context.save()
        XCTAssertNotEqual(imported.details, preloadDish.details, "Fixture needs details with lowercase letters")

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.details, preloadDish.details.uppercased())
        XCTAssertTrue(menu.dishes?.contains(imported) ?? false)
    }

    func testIngredientUnitSubstitutionWinsOverMenuLinkedSeedCopy() throws {
        let seed = try makeSeedCopy()
        let menu = menuLinking(seed)
        // Same product name and quantity, but the user picked a product measured in another unit
        let imported = try makeSeedCopy()
        let ingredient = try XCTUnwrap((imported.ingredientDetails as? Set<IngredientDetail>)?.first)
        let productName = try XCTUnwrap(ingredient.product?.name)
        ingredient.product = createProduct(name: productName, unit: unit("Other unit"))
        try context.save()

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertTrue(menu.dishes?.contains(imported) ?? false)
    }

    func testTwoEditedRecordsAreBothKept() throws {
        // A seed copy edited and saved locally, and a differently edited imported record
        let local = try makeSeedCopy()
        local.details = "Edited on this device"
        let imported = try makeSeedCopy()
        imported.details = "Edited on another device"
        try context.save()

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        // Neither is deleted here; `cleanupDuplicateDishes` merges them afterwards
        let details = try context.fetch(Dish.fetchRequest()).compactMap(\.details)
        XCTAssertEqual(Set(details), ["Edited on this device", "Edited on another device"])
    }

    func testSeedCopiesOnlyKeepMenuLinkedOne() throws {
        _ = try makeSeedCopy()
        let linked = try makeSeedCopy()
        let menu = menuLinking(linked)

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertTrue(menu.dishes?.contains(linked) ?? false)
    }
}
