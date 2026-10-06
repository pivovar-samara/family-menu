# Contributing to Family Menu Planner

Thank you for your interest in contributing! This guide will help you get started.

## Getting Started

### Prerequisites

- macOS with Xcode 16.3+
- iOS 17.0+ Simulator (iPhone 17 recommended)
- Swift 5.9+

### Setup

1. Fork and clone the repository
2. Copy `Configs/Secrets.xcconfig.example` to `Configs/Secrets.xcconfig` and fill in your API keys (or leave empty for development without analytics)
3. Open `FamilyMenuPlanner.xcodeproj` in Xcode
4. Build and run on the iOS Simulator

## How to Contribute

### Reporting Bugs

- Open a GitHub Issue with a clear description of the bug
- Include steps to reproduce, expected behavior, and actual behavior
- Mention your Xcode version and iOS Simulator version

### Suggesting Features

- Open a GitHub Issue describing the feature and why it would be useful
- Discuss the approach before starting implementation

### Submitting Changes

1. Create a branch from `main` for your changes
2. Follow the existing MVVM + Coordinators architecture
3. Localize all user-facing strings using `.localized()`
4. Add unit and integration tests for new logic
5. Ensure all existing tests pass before submitting
6. Open a Pull Request with a clear description of your changes

## Code Style

- Follow the existing project conventions and architecture patterns
- Use `AppLogger` for logging instead of `print` statements
- Use `BackgroundOperationManager` for heavy Core Data operations
- Add accessibility identifiers and semantic labels to new UI elements
- Use card-based layouts consistent with the existing design system

## Running Tests

```bash
# All tests
xcodebuild test \
  -scheme FamilyMenuPlanner \
  -project FamilyMenuPlanner.xcodeproj \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -testPlan FamilyMenuPlanner-Full \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
