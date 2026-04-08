# Project Rules

- Do not add any Claude or Anthropic authorship references (Co-Authored-By, comments, documentation, commit messages, or otherwise) anywhere in this project.

# Build & Test

- Build: `swift build` or `make build` (release)
- Test: `swift test` or `make test`
- Deploy: `make deploy` (builds, bundles, installs to /Applications)
- Generate Xcode project: `swift package generate-xcodeproj`

# Architecture

Upkeep is a SwiftUI macOS app for tracking home maintenance inventory and logging maintenance work. Data is persisted as JSON files in `~/.upkeep/` via a `Persistence` actor.

- Uses Swift 6.0 Testing framework (`@Test`, `#expect`), not XCTest
- macOS 15.0+ only, no external dependencies
- `@Observable` + `@MainActor` for state management
- File-based JSON persistence with split storage (see Data Storage below)

# Data Storage

Storage is split between shared and local directories:

## Shared data (configurable via Settings > Data Location)
Default: `~/.upkeep/`. Can be pointed at a synced folder (e.g. Google Drive) for household sharing.
- `items/` — maintenance items (one JSON file per item, named by UUID)
- `log/` — log entries
- `vendors/` — vendor records
- `photos/` — attached photos
- `config.json` — app-wide settings (reminders, dashboard prefs)
- `home.json` — home profile and major systems
- `members.json` — household members

## Local data (always `~/.upkeep/`, never synced)
- `backups/` — backup ZIP archives

## Instance config (always `~/Library/Application Support/Upkeep/`)
- `local-config.json` — current member ID, custom data path, UI prefs

## Setting up shared storage
1. Create a folder in Google Drive (or other sync service)
2. Copy shared data: `cp -R ~/.upkeep/{items,log,vendors,photos,config.json,home.json,members.json} "/path/to/Google Drive/Upkeep/"`
3. In Upkeep, go to Settings > Data Location > Change... and select the Google Drive folder
4. Backups remain local in `~/.upkeep/backups/`

# Data Flow

MaintenanceItems (the inventory) define what needs recurring maintenance and how often.
LogEntries record when maintenance was actually performed, with optional cost and vendor info.
LogEntries can be standalone (one-off work) or linked to a MaintenanceItem.
Due dates are computed from the last LogEntry date + the item's frequency.

# Maintenance Rules

When source code changes, the following files must be kept in sync:

## View/Feature Changes
When views or features are added or modified:
- Update contextual empty states where appropriate
- Add keyboard shortcuts for new primary actions

## Model Changes
When data models are modified:
- Ensure JSON encoding/decoding round-trips correctly
- Update `UpkeepStore` if the model change affects state management
- Update detail views if display fields change
- Add or update tests in `Tests/UpkeepTests/`

## Persistence Changes
When file storage format or paths change:
- Update methods in `Services/Persistence.swift`

## Function/API Changes
When exported or public functions/computed properties are added or modified:
- Add or update corresponding unit tests to cover the new/changed behavior
- Test edge cases, error paths, and boundary conditions
