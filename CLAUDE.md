@AGENTS.md

## Claude Code notes

- Before calling a change done, build and run the relevant tests with `xcodebuild` (commands above); for UI changes also run the affected `FamilyMenuPlannerUITests` class and check `runtimeWarnings` in the result bundle.
- Run long `xcodebuild test` invocations in the background; UI suites take several minutes.
- Keep `AGENTS.md` as the single source of project guidance; put only Claude-specific notes here.
