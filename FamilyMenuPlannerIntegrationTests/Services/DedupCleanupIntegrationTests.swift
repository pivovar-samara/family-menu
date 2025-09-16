import XCTest
import CoreData
@testable import FamilyMenuPlanner

final class DedupCleanupIntegrationTests: BaseIntegrationTest {
    func testDishAndMenuDedupCleanup() throws {
        // Arrange
        let category = createDishCategory(name: "Main Course")

        let dish = createDish(name: "Test Dish", category: category)
        let duplicateDish = createDish(name: "Test Dish", category: category)

        // Create two duplicate menus for the same slot that reference the two duplicate dishes
        let menu1 = Menu(context: context)
        menu1.day = "Mon"
        menu1.mealType = "Lunch"
        menu1.calendarWeek = 0
        menu1.addToDishes(dish)

        let menuDup = Menu(context: context)
        menuDup.day = "Mon"
        menuDup.mealType = "Lunch"
        menuDup.calendarWeek = 0
        menuDup.addToDishes(duplicateDish)

        try context.save()

        // Act: run dedup routines from persistence
        PersistenceController.shared.cleanupDuplicateDishes(context: context)
        PersistenceController.shared.cleanupDuplicateMenus(context: context)

        // Assert: one dish remains
        let dishFetch: NSFetchRequest<Dish> = Dish.fetchRequest()
        let dishes = try context.fetch(dishFetch)
        XCTAssertEqual(dishes.count, 1)

        // Assert: one menu remains for the same slot and it has one dish
        let menuFetch: NSFetchRequest<Menu> = Menu.fetchRequest()
        let menus = try context.fetch(menuFetch)
        XCTAssertEqual(menus.count, 1)
        XCTAssertEqual(menus.first?.dishes?.count, 1)
    }
}


