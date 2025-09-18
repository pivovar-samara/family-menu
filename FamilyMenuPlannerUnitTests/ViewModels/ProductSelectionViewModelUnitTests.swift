import XCTest
import CoreData
@testable import FamilyMenuPlanner

// MARK: - Mock Service for Unit Tests
final class MockProductSelectionServiceForUnitTests: ProductSelectionServiceProtocol {
    var productsToReturn: [Product] = []
    func fetchAllProducts() -> [Product] { productsToReturn }
}

final class ProductSelectionViewModelUnitTests: XCTestCase {
    var context: NSManagedObjectContext!
    var service: MockProductSelectionServiceForUnitTests!

    override func setUp() {
        super.setUp()
        context = TestCoreDataStack.shared.viewContext
        service = MockProductSelectionServiceForUnitTests()
    }

    override func tearDown() {
        service = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers
    private func createUnit(name: String = "pcs") -> Unit {
        let unit = Unit(context: context)
        unit.name = name
        unit.sortOrder = 0
        XCTAssertNoThrow(try context.save())
        return unit
    }

    private func createProduct(name: String, unit: Unit?) -> Product {
        let product = Product(context: context)
        product.name = name
        product.unit = unit
        product.isDraft = false
        XCTAssertNoThrow(try context.save())
        return product
    }

    // MARK: - Tests
    func testHandleNewProductSaved_SingleSelection_SelectsAndCallbacks() {
        // Given
        let unit = createUnit()
        let newProduct = createProduct(name: "UnitTest Product", unit: unit)
        service.productsToReturn = [newProduct]

        var callbackProduct: Product? = nil
        let viewModel = ProductSelectionViewModel(
            productSelectionService: service,
            currentProduct: nil,
            selectionMode: .single,
            preselectedProducts: [],
            onProductSelected: { product in callbackProduct = product },
            onProductsSelected: nil
        )

        // When
        viewModel.handleNewProductSaved(newProduct)

        // Then
        XCTAssertEqual(viewModel.selectedProduct, newProduct)
        XCTAssertEqual(callbackProduct, newProduct)
    }

    func testHandleNewProductSaved_MultipleSelection_PreselectsNewProduct() {
        // Given
        let unit = createUnit()
        let newProduct = createProduct(name: "MultiSelect New Product", unit: unit)
        service.productsToReturn = [newProduct]

        let viewModel = ProductSelectionViewModel(
            productSelectionService: service,
            currentProduct: nil,
            selectionMode: .multiple,
            preselectedProducts: [],
            onProductSelected: { _ in },
            onProductsSelected: { _ in }
        )

        // When
        viewModel.handleNewProductSaved(newProduct)

        // Then
        XCTAssertTrue(viewModel.selectedProducts.contains(newProduct))
        XCTAssertNil(viewModel.selectedProduct)
    }
}


