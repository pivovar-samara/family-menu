## Testing

Unit tests are included for each key component of the app, covering the menu logic, persistence, and UI models. All tests are designed to run efficiently with proper context management and realistic performance characteristics.

### UI Tests configuration and assumptions

The UI tests (e.g., `MenuManagementUITests`) run with specific launch arguments and environment variables to ensure deterministic behavior in Simulator:

- Launch Arguments:
  - `-UITests`
  - `-DisableCloudKit`
  - `-XCTest`
- Environment Variables:
  - `UI_TESTS=1`
  - `DISABLE_CLOUDKIT=1`
  - `XCTestBundlePath=UITests`

These settings disable CloudKit sync during UI tests and mark the process as a test environment.

#### Required accessibility identifiers and labels
UI tests rely on consistent accessibility to navigate and validate UI. Ensure the following identifiers/labels exist:

- Navigation and tabs
  - Tab bar button labeled `Menu`
  - Navigation bar titles: `Menu`, `Select Dish`
- Buttons in the Menu screen navigation bar
  - `Shopping List`
  - `Generate Menu`
- Dish selection screen
  - A toolbar/navigation button with identifier `dish_selection_done_button` used as the Done action
  - A searchable field available via `app.searchFields.firstMatch`
- Context menus / actions
  - Context menu buttons labeled `Clear Dishes` and `Clear All Day`
- Icons / images
  - Pencil icon inside meal buttons exposed with accessibility identifier or label `pencil`

#### Alerts and flows assumed by tests
- Generating a new menu shows an alert titled `Generate New Menu` with the message `This will overwrite the current menu. Are you sure?` and buttons `Cancel` and `Generate`.
- Editing past dates may show a warning alert titled `Warning` with a `Continue` button; tests are resilient to its presence.

#### Localization expectations
UI tests look for English strings like day names (`Monday`…`Sunday`) and meal types (`Breakfast`, `Lunch`, `Dinner`). When running UI tests in other locales, update tests or ensure the app launches in English for consistency.

#### Simulator & platform
UI tests are designed to run on iOS Simulator (e.g., iPhone 17, iOS 26). CloudKit is disabled for UI tests by default.

#### Notes on search interactions
Tests include robust handling for clearing search text (e.g., tapping the clear button or using a helper). Make sure the search field exposes the standard clear button labeled `Clear text` where possible.

