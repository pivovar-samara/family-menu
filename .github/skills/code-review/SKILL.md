---
name: code-review
description: Review checklist for the FamilyMenuPlanner iOS app (SwiftUI, MVVM + Coordinators, Core Data + CloudKit, Xcode Cloud CI). Use when reviewing pull requests in this repository.
---

# FamilyMenuPlanner code review

Project conventions (architecture, modules, utilities) are described in `.github/copilot-instructions.md`. Use them as the baseline; this skill lists what to check in a diff. Report concrete bugs with a failure scenario first, style issues last. Skip nits the compiler or Xcode already flags.

## Localization

- User-facing strings go through `.localized()` (`FamilyMenuPlanner/Common/LocalizationHelper.swift`), which wraps `NSLocalizedString`.
- **Never interpolate before `.localized()`**: `"Contact \(email)".localized()` looks up a key that doesn't exist and is never translated. Require `String(format: "Contact %@".localized(), email)` with a matching `%@` key in `Localizable.xcstrings`.
- New keys must be added to `FamilyMenuPlanner/Resources/Localizable.xcstrings` with both `en` and `ru` translations.
- Flag keys that differ only by case or punctuation (e.g. `"Edit product"` vs `"Edit Product"`): they are confusing to translate and break the build if string-catalog symbol generation is turned on.
- Strings used only via `.localized()` are not seen by Xcode's extraction, so they must stay `"extractionState" : "manual"`. Flag diffs that mark them `stale` or delete them — that silently drops translations.
- Seed data changes must be made in both `Resources/en.lproj/preloadData.json` and `Resources/ru.lproj/preloadData.json`.

## Dates and weeks

- Weeks start on Monday. Week math must use `CalendarHelper` (`startOfWeek`, Monday-first) rather than `Calendar.current` with `.yearForWeekOfYear/.weekOfYear`: `Calendar.current` follows the device region, and in Sunday-first regions (US) the "current week" resolves to the previous one.
- Menus are stored and looked up by week number. Any change to how week numbers are computed must keep existing saved menus resolvable (or migrate them).
- Tests that depend on "today" or the weekday must be deterministic: inject the date/calendar or pin it, don't rely on the machine's region or the day the test runs.

## Core Data and CloudKit

- Heavy or bulk work goes through `BackgroundOperationManager` / background contexts, never on the view context on the main thread.
- Don't pass `NSManagedObject` instances across contexts or threads; pass `NSManagedObjectID`.
- Model changes (`FamilyMenuPlanner.xcdatamodeld`) must be lightweight-migration compatible and CloudKit compatible: no unique constraints, new attributes optional or with defaults, relationships optional with inverses.
- Code that seeds or deduplicates data must stay safe when CloudKit imports the same records on another device (see the reconciliation in `Persistence.swift` / `AppStateManager.swift`).
- CloudKit must stay disabled in tests and CI. Don't remove the environment checks (`XCTestConfigurationFilePath`, `CI`, `UI_TESTS`, `-UITests`, `-DisableCloudKit`).

## SwiftUI and view models

- Views stay thin: logic belongs in the ViewModel, persistence in the Service, navigation in the Coordinator.
- `@Published` state is mutated on the main actor. Flag "Publishing changes from within view updates" patterns (mutating state inside `body`, `onChange` chains that write back synchronously).
- Use `AppLogger`, not `print`.
- New interactive elements need accessibility identifiers; UI tests depend on them (`dish_list_item_*`, `add_dish_button`, …).
- Analytics events use the constants in `FamilyMenuPlanner/Analytics/`, not string literals.

## Tests

- New ViewModel/helper logic needs unit tests; new Service + Core Data behavior needs integration tests. Use `TestDataFactory` (`FamilyMenuPlannerIntegrationTests/BaseIntegrationTests/`) for entities.
- UI tests: locate elements by accessibility identifier, wait with `waitForExistence`, and avoid gestures that start mid-list (they can tap a card instead of scrolling). A search field under a large title is hidden until the list is pulled down from the navigation bar.
- Flag tests that pass vacuously (`XCTAssertTrue(true)` in the branch where the feature wasn't found).
- Test plans: `FamilyMenuPlanner-PR.xctestplan` (Unit + Integration, default) and `FamilyMenuPlanner-Full.xctestplan` (all suites). A new test target must be added to the right plan, otherwise CI never runs it.

## CI, configuration, and secrets

- CI is Xcode Cloud. `ci_scripts/ci_post_clone.sh` writes `Configs/Secrets.xcconfig`; `ci_scripts/ci_pre_xcodebuild.sh` fails archives without the right Amplitude key (`_PROD` for tag builds, `_DEV` otherwise). Changes to these scripts must keep that contract.
- Never commit `Configs/Secrets.xcconfig` or real API keys. New secrets go through `Secrets.xcconfig.example` + Xcode Cloud environment variables.
- `Package.resolved` must be committed and updated with any Swift package change; Xcode Cloud does not resolve packages on its own.
- Changes to the shared scheme, test plans, or `project.pbxproj` build settings deserve a close look: unexpected Xcode rewrites (signing team, deployment target, `STRING_CATALOG_GENERATE_SYMBOLS`) are easy to commit by accident.
