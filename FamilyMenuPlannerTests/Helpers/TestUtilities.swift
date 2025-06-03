import XCTest

// MARK: - Mock Classes for Unit Tests
class MockMealType: Hashable {
    let name: String
    let sortOrder: Int16
    init(name: String, sortOrder: Int16 = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
    static func == (lhs: MockMealType, rhs: MockMealType) -> Bool {
        lhs.name == rhs.name && lhs.sortOrder == rhs.sortOrder
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(sortOrder)
    }
}

class MockDishCategory: Hashable {
    let name: String
    let sortOrder: Int16
    init(name: String, sortOrder: Int16 = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
    static func == (lhs: MockDishCategory, rhs: MockDishCategory) -> Bool {
        lhs.name == rhs.name && lhs.sortOrder == rhs.sortOrder
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(sortOrder)
    }
}

class MockDish: Hashable {
    let name: String?
    let details: String?
    var mealTypes: Set<MockMealType>
    var category: MockDishCategory?
    init(name: String?, details: String? = nil, mealTypes: Set<MockMealType> = [], category: MockDishCategory? = nil) {
        self.name = name
        self.details = details
        self.mealTypes = mealTypes
        self.category = category
    }
    static func == (lhs: MockDish, rhs: MockDish) -> Bool {
        lhs.name == rhs.name && lhs.mealTypes == rhs.mealTypes && lhs.category == rhs.category
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(mealTypes)
        hasher.combine(category)
    }
}

class MockUnit: Hashable {
    let name: String
    let sortOrder: Int16
    
    init(name: String, sortOrder: Int16) {
        self.name = name
        self.sortOrder = sortOrder
    }
    
    static func == (lhs: MockUnit, rhs: MockUnit) -> Bool {
        lhs.name == rhs.name && lhs.sortOrder == rhs.sortOrder
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(sortOrder)
    }
}

class MockProduct: Hashable {
    var name: String?
    var unit: MockUnit?
    
    init(name: String?, unit: MockUnit?) {
        self.name = name
        self.unit = unit
    }
    
    static func == (lhs: MockProduct, rhs: MockProduct) -> Bool {
        lhs.name == rhs.name && lhs.unit == rhs.unit
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(unit)
    }
}

class MockIngredientDetail {
    var dish: MockDish?
    var product: MockProduct?
    var quantity: Double = 0.0
    var sortOrder: Int16 = 0
}
