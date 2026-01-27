// CLAUDE.md
# OpenRouter SwiftUI Application – Development Guide

## Quick Start Commands
```bash
# Build for iOS (Simulator)
xcodebuild -scheme Openrouter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean build

# Build for macOS
xcodebuild -scheme Openrouter -destination 'platform=macOS' clean build

# Run unit & UI tests
xcodebuild test -scheme Openrouter -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Project manipulation (xcp)
xcp list-targets          # list all Xcode targets
xcp list-groups           # list groups in the project

# SourceKit LSP (experimental mode)
xcode-build-server config -scheme Openrouter -workspace Openrouter.xcodeproj
```

## Architecture Overview
- **Persistence**: SwiftData models stored in CloudKit (`ModelConfiguration(..., cloudKitDatabase: .automatic)`).  
- **Models** (9): `AIModel`, `ModelPricing`, `ModelProvider`, `ModelArchitecture`, `ModelParameters`, `ChatSession`, `ChatMessage`, `UserPreferences`, `DailyCostLog`.  
- **MVVM**: Views bind to `@Query`‑backed view models; services perform networking and business logic.  
- **Services**:
  - `NetworkManager` – centralised URLSession wrapper with retry logic.
  - `OpenRouterClient` – regional endpoint handling, chat & model endpoints.
  - `KeychainManager` – secure storage of API keys.
  - `ModelImportService` – one‑time import of bundled model catalog.
  - `SubscriptionManager` – in‑app purchase handling.
- **Navigation**: `TabView` with four tabs – Models, Chats, Analytics, Settings.  
- **Critical Files**: `OpenrouterApp.swift`, `ContentView.swift`, all files under `Models/`, `Services/`, `Views/`.

## Data Flow Patterns
1. **SwiftData ↔ UI**  
   - `@Query` in view models automatically refresh UI when the underlying model changes.  
   - CloudKit sync propagates changes across devices; offline edits are persisted locally and merged later.

2. **Network → Service → View**  
   - Views call service methods (e.g., `OpenRouterClient.sendChat`).  
   - `NetworkManager` performs the request, applies exponential back‑off retries, and returns raw `Data`.  
   - Service decodes JSON into Swift structs and returns them to the view model.

3. **Cost Tracking**  
   - Each `ChatMessage` records token usage.  
   - `DailyCostLog` aggregates usage per day; `UserPreferences` stores budget limits.  
   - UI in `UsageTrackerView` reads these logs via `@Query` and presents charts.

4. **Security**  
   - API keys are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.  
   - No keys are ever written to UserDefaults or plain files.

## Known Issues & Proposed Fixes
| Issue | Description | Proposed Fix |
|-------|-------------|--------------|
| **Model import runs on every launch** | `OpenrouterApp` runs `ModelImportService.importModels` inside a `.task` on `ContentView`, causing duplicate imports. | Add a `UserDefaults` flag `hasImportedModels`. Check the flag before importing; set it to `true` after the first successful import. |
| **AppState not integrated** | `AppState.swift` exists but is never injected into the SwiftUI environment, so import progress and global state are inaccessible. | Inject `AppState` via `.environmentObject(appState)` in `OpenrouterApp`’s `WindowGroup`. Views that need state should declare `@EnvironmentObject var appState: AppState`. |
| **Silent error handling** | Import failures are only printed to the console (`print("Failed to import models: …")`). Users receive no feedback. | Add a `@State var importError: Error?` in `ContentView` (or a dedicated view). Present an `Alert` when `importError` is non‑nil, offering a retry button. |
| **Obsolete `Item.swift` model** | The template `Item` model is no longer used, but the preview in `ContentView.swift` still references it, causing compile errors. | Remove the preview block (done) and delete `Item.swift` from the project (`git rm Openrouter/Item.swift`). |

*References*:  
- Managing model data in SwiftUI: https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app  
- SwiftData & CloudKit best practices (Apple WWDC 2023 Session “Introducing SwiftData”).  

## Development Guidelines
- **Never** store API keys in plain files or `UserDefaults`. Use `KeychainManager`.  
- **SwiftData cascade deletes**: Deleting a `ChatSession` should automatically delete its related `ChatMessage`s (configured via model relationships).  
- **Budget enforcement**: Validate token usage against `UserPreferences.dailyBudget` before sending a request; surface warnings in the UI.  
- **Testing**: Add unit tests for `OpenRouterClient` (mock `NetworkManager`) and UI tests for tab navigation and error alerts.  
- **HIG compliance**:  
  - Use SF Symbols for tab icons (already done).  
  - Present errors with `Alert`.  
  - Show loading states with `ProgressView`.  
  - Keep Settings in a dedicated tab.  

## Repository Hygiene
- **.gitignore** (see file below) excludes build artefacts, derived data, SwiftData SQLite files, and any secrets.  
- All new model, service, and view files are tracked; the obsolete `Item.swift` has been removed.  

---  
*End of CLAUDE.md*  
