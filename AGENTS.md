# AGENTS.md

Guidance for AI coding agents working in this repository. Product overview is in `README.md`; a longer module-by-module tour is in `.github/copilot-instructions.md`; the review checklist is in `.github/skills/code-review/SKILL.md`.

## Project at a glance

- iOS app (SwiftUI, Core Data + CloudKit), MVVM + Coordinators. Single Xcode project, no workspace: `FamilyMenuPlanner.xcodeproj`.
- Deployment target **iOS 17.1**. `SWIFT_VERSION = 5.0` (Swift 5 language mode, compiled by the current Swift 6.x toolchain) — no strict concurrency checking.
- One SPM dependency: `AmplitudeSwift`. `Package.resolved` lives under `FamilyMenuPlanner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` and must stay committed (Xcode Cloud does not resolve packages).
- Localized in English and Russian.

## Commands

There is one scheme, `FamilyMenuPlanner`, with two test plans: `FamilyMenuPlanner-PR` (default; Unit + Integration) and `FamilyMenuPlanner-Full` (adds Performance + UI, 60s/120s timeouts). UI and Performance targets are only in the Full plan, so `-only-testing` for them needs `-testPlan FamilyMenuPlanner-Full`.

```bash
# Build (incl. test targets)
xcodebuild build-for-testing -project FamilyMenuPlanner.xcodeproj -scheme FamilyMenuPlanner \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" CODE_SIGNING_ALLOWED=NO

# PR tests (what CI runs on pull requests)
xcodebuild test -project FamilyMenuPlanner.xcodeproj -scheme FamilyMenuPlanner \
  -testPlan FamilyMenuPlanner-PR -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" CODE_SIGNING_ALLOWED=NO

# A single test class / method (UI example)
xcodebuild test -project FamilyMenuPlanner.xcodeproj -scheme FamilyMenuPlanner \
  -testPlan FamilyMenuPlanner-Full -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" \
  -only-testing:FamilyMenuPlannerUITests/MenuManagementUITests/testGenerateNewMenu
```

- **Always run tests on the iPhone 18 Pro simulator with iOS 27.0** (requires Xcode 27.0+). Don't substitute another device or runtime; if it's missing, say so instead of falling back. Check with `xcrun simctl list devices available`.
- To build with a non-default Xcode (e.g. a beta), prefix with `DEVELOPER_DIR="/Applications/Xcode beta.app/Contents/Developer"`.
- Use `-resultBundlePath <path>.xcresult` and inspect with `xcrun xcresulttool get test-results summary --path <path>`; SwiftUI **runtime warnings** (e.g. "Publishing changes from within view updates") appear there under `runtimeWarnings`, not as test failures.
- `xcodebuild` sometimes hangs after "Executed N tests" while finalizing the result bundle; the test outcome is already in the log.
- Local setup: copy `Configs/Secrets.xcconfig.example` to `Configs/Secrets.xcconfig` (gitignored — never commit it). Empty keys are fine; analytics is then disabled.

## Layout

```
FamilyMenuPlanner/
  FamilyMenuPlannerApp.swift, ContentView.swift
  AppStateManager.swift      # @MainActor startup state, CloudKit seeding gate, error UI
  Persistence.swift          # PersistenceController: store setup, preload data, dedup/reconciliation
  Menu/{BaseMenu,DishSelection,ShoppingList}/
  Dishes/{DishList,DishDetails,ProductSelection}/
  Products/{ProductList,Product}/
  Common/                    # AppLogger, BackgroundOperationManager, CalendarHelper, AlertQueueManager, caches, UI helpers
  Analytics/                 # AnalyticsEventName / AnalyticsPropertyKey constants, Amplitude provider
  Resources/                 # Localizable.xcstrings, {en,ru}.lproj/preloadData.json, assets
FamilyMenuPlannerUnitTests/          # mocked services
FamilyMenuPlannerIntegrationTests/   # real in-memory Core Data; TestDataFactory in BaseIntegrationTests/
FamilyMenuPlannerPerformanceTests/
FamilyMenuPlannerUITests/            # Flows/, PageObjects/, Helpers/
```

A feature module is `XxxView` + `XxxViewModel` + `XxxService` (Core Data) + `XxxCoordinator` (builds the view model with its service and returns the view).

## Conventions

**Localization**
- All user-facing text goes through `.localized()` (`Common/LocalizationHelper.swift`). Never interpolate before localizing: use `String(format: "Today is %@".localized(), value)`.
- Add new keys to `Resources/Localizable.xcstrings` with both `en` and `ru`; keys used only via `.localized()` must keep `"extractionState" : "manual"`.
- Seed data changes go into both `en.lproj` and `ru.lproj/preloadData.json`, and bump `currentPreloadDataVersion` in `Persistence.swift`.

**Dates and weeks**
- Weeks are Monday-first. Use `CalendarHelper` (`startOfWeek`, `weekCalendar`, `date(forDayIndex:inWeekOf:)`), never `Calendar.current` week components — they follow the device region.
- Menus are keyed by week; changes to week math must keep existing saved menus resolvable or migrate them.
- Inject `now`/`calendar` (see `MenuViewModel.init`) so tests don't depend on the current date or region.

**Core Data / CloudKit**
- Heavy or bulk work goes through `BackgroundOperationManager` / background contexts; pass `NSManagedObjectID` across contexts, not managed objects.
- Model changes must be lightweight-migration and CloudKit compatible: no unique constraints, new attributes optional or defaulted, relationships optional with inverses. Entity classes are Xcode-generated (`codeGenerationType="class"`).
- Seeding and dedup must stay correct when another device imports the same records (see `AppStateManager` seeding gate and reconciliation in `Persistence.swift`).
- CloudKit must stay disabled in tests/CI. Do not remove the environment checks (`XCTestConfigurationFilePath`, `CI`, `UI_TESTS`, `-UITests`, `-DisableCloudKit`).

**SwiftUI state**
- New and migrated view models use the Observation framework: `@Observable` class, owned with `@State`, passed as a plain property, `@Bindable` where `$` bindings are needed. `MenuViewModel` is the reference example; other view models are still `ObservableObject` and are migrated incrementally.
- Pure presentation state (is an alert/sheet shown) lives in the view as `@State`, not in the view model.
- Keep `@Observable` initializers cheap: `@State(initialValue:)` evaluates its argument on every view re-init.
- `AlertQueueManager` stays `ObservableObject`: several view models subscribe to `$currentAlert` via Combine.
- Do not mutate observable state inside `body` or synchronously from binding getters. On iOS 27, alerts bound to an `ObservableObject`'s `@Published` flag emit "Publishing changes from within view updates" when dismissed.

**Other**
- Log with `AppLogger` (with a category), not `print`.
- Analytics: use `AnalyticsEventName` / `AnalyticsPropertyKey` constants, never string literals.
- Every interactive element needs an accessibility identifier; UI tests and page objects rely on them.

## Testing notes

- Every logic change needs unit and/or integration tests; debug-only views are not tested.
- Use `TestDataFactory` (`FamilyMenuPlannerIntegrationTests/BaseIntegrationTests/`) for Core Data fixtures.
- UI tests launch with `-UITests -DisableCloudKit` and a persistent store. Menu UI tests edit the current week, so on any day after Monday they hit the "editing a past date" alert and accept it (`handlePastEditAlertIfPresent`); keep that path working.
- After a toolchain or iOS update, run the Full plan and check `runtimeWarnings` in the xcresult, not just pass/fail.

## Git and CI

- Branch from `main` with prefixes `feature/`, `fix/`, `bug/`, `ci/`; open PRs against `main`.
- CI is Xcode Cloud (workflows configured in App Store Connect): PRs run the PR plan; pushes to `main` build to TestFlight; tags release to the App Store. `ci_scripts/ci_post_clone.sh` writes `Configs/Secrets.xcconfig` from workflow env vars; `ci_pre_xcodebuild.sh` fails archives missing the Amplitude key.
