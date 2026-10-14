import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// After an iCloud reconnect the store can hold a locally seeded preload dish and the imported record with the
/// same key; the imported one may carry the user's edits and must win.
final class SeededDishReconciliationIntegrationTests: BaseIntegrationTest {
    private let seededKey = "LocallySeededDishURIs"
    private var savedSeededURIs: Any?

    override func setUp() {
        super.setUp()
        savedSeededURIs = UserDefaults.standard.object(forKey: seededKey)
        UserDefaults.standard.removeObject(forKey: seededKey)
    }

    override func tearDown() {
        if let savedSeededURIs {
            UserDefaults.standard.set(savedSeededURIs, forKey: seededKey)
        } else {
            UserDefaults.standard.removeObject(forKey: seededKey)
        }
        super.tearDown()
    }

    func testImportedRecordWinsOverMoreConnectedLocalSeedCopy() throws {
        let breakfast = createMealType(name: "Breakfast")
        let lunch = createMealType(name: "Lunch")

        // The user's edited version, imported from iCloud: fewer relationships, not in any menu
        let imported = createDish(name: "Greek salad", details: "Edited by the user")
        imported.key = "greek_salad"

        // Fresh local seed copy of the same preload dish, already placed in a menu
        let seeded = Dish(context: context)
        seeded.name = "Greek salad"
        seeded.details = "Preload details"
        seeded.key = "greek_salad"
        seeded.isDraft = false
        seeded.addToMealTypes(breakfast)
        seeded.addToMealTypes(lunch)
        try PersistenceController.shared.saveRecordingLocallySeededDishes(context: context)
        let menu = testDataFactory.createMenu(weekStartDate: Date(), dish: seeded, mealType: lunch)
        XCTAssertEqual(PersistenceController.locallySeededDishURIs.count, 1)

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.details, "Edited by the user")
        XCTAssertEqual(menu.dishes?.count, 1)
        XCTAssertTrue(menu.dishes?.contains(imported) ?? false)
        XCTAssertTrue(PersistenceController.locallySeededDishURIs.isEmpty)
    }

    func testUnrecordedExactPreloadCopyLosesToEditedRecord() throws {
        // A seed copy from before provenance was recorded: identical to its preload dish, in a menu
        let url = try XCTUnwrap(Bundle.main.url(forResource: "preloadData", withExtension: "json"))
        let preload = try JSONDecoder().decode(PreloadedData.self, from: Data(contentsOf: url))
        let preloadDish = try XCTUnwrap(preload.dishes.first { !$0.ingredients.isEmpty })
        let unit = createUnit(name: "unit")
        let lunch = createMealType(name: "Lunch")

        let legacySeed = createDish(name: preloadDish.name, details: preloadDish.details)
        legacySeed.key = "legacy-key"
        for ingredientData in preloadDish.ingredients {
            let ingredient = IngredientDetail(context: context)
            ingredient.dish = legacySeed
            ingredient.product = createProduct(name: ingredientData.product, unit: unit)
            ingredient.quantity = ingredientData.quantity
        }
        try context.save()
        let menu = testDataFactory.createMenu(weekStartDate: Date(), dish: legacySeed, mealType: lunch)

        // The user's edited version, imported from iCloud
        let edited = createDish(name: preloadDish.name, details: "Edited by the user")
        edited.key = "legacy-key"
        try context.save()

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.details, "Edited by the user")
        XCTAssertTrue(menu.dishes?.contains(edited) ?? false)
    }

    func testDuplicatesWithoutLocalSeedKeepMenuLinkedDish() throws {
        let lunch = createMealType(name: "Lunch")
        let first = createDish(name: "Soup", details: "First")
        first.key = "soup"
        let second = createDish(name: "Soup", details: "Second")
        second.key = "soup"
        second.addToMealTypes(lunch)
        try context.save()
        let menu = testDataFactory.createMenu(weekStartDate: Date(), dish: first, mealType: lunch)

        PersistenceController.shared.removeLocallySeededDishesIfRemoteExists(context: context)

        let dishes = try context.fetch(Dish.fetchRequest())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.details, "First")
        XCTAssertTrue(menu.dishes?.contains(first) ?? false)
    }
}
