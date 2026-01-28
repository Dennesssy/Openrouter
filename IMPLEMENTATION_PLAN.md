# Implementation Plan: OpenRouter SwiftUI App - CLAUDE.md Creation & Repository Audit

## Overview
Create comprehensive CLAUDE.md documentation for the OpenRouter SwiftUI application, review uncommitted changes for alignment with Apple's SwiftUI data management best practices, update .gitignore, and ensure HIG (Human Interface Guidelines) compliance.

## Phase 1: Repository Analysis (COMPLETED)

**Findings:**
1. **Project Structure**: Multi-platform SwiftUI app (iOS, macOS, visionOS) using SwiftData + CloudKit
2. **Architecture**: MVVM with 9 SwiftData models, 5 services, 8 views
3. **Uncommitted Changes**: Migration from template "Item" model to full OpenRouter implementation
4. **Missing Files**: No .gitignore, no existing CLAUDE.md
5. **Potential Issues**:
   - AppState.swift not integrated with OpenrouterApp.swift (unused container reference)
   - Model import runs on every app launch (.task in WindowGroup)
   - No error recovery UI for import failures

## Phase 2: SwiftUI Data Management Alignment Issues

**Identified Misalignments with Apple Documentation:**

### Issue 1: Model Import Execution Context
**Current:** Model import runs in `.task` modifier on ContentView
**Apple Best Practice:** Data initialization should happen during ModelContainer setup or use `@Query` with proper error handling
**Impact:** Import runs every app launch, not just first launch
**Reference:** https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app

### Issue 2: AppState Not Integrated
**Current:** AppState.swift exists but not injected into SwiftUI environment
**Apple Best Practice:** Use `@Environment` or `@EnvironmentObject` for app-wide state
**Impact:** State tracking for import progress is non-functional

### Issue 3: Error Handling Pattern
**Current:** Print to console with no user feedback
**Apple Best Practice:** Use @State for error alerts, present errors to user
**Impact:** Silent failures, poor user experience

## Phase 3: CLAUDE.md Content Structure (2-3 Pages, Balanced Approach)

**User Preferences Applied:**
- Balanced length (2-3 pages)
- Core commands with brief explanations
- Document issues + propose detailed fixes for later
- Brief mention of xcp/xcode-build-server tools
- Git staging: use complete OpenRouterClient.swift version

**Sections to Include:**

### 1. Quick Start Commands (1/2 page)
- Build for iOS, macOS, visionOS (essential xcodebuild commands)
- Run tests (unit and UI)
- Brief mention: xcp for project manipulation, xcode-build-server for LSP

### 2. Architecture Overview (3/4 page)
- SwiftData + CloudKit persistence with 9 models
- MVVM pattern with @Query reactive bindings
- Service layer: NetworkManager (retry logic), OpenRouterClient (regional endpoints), KeychainManager (secure storage)
- Tab navigation: Models → Chats → Analytics → Settings
- Critical paths: OpenrouterApp.swift, Models/, Services/, Views/

### 3. Data Flow Patterns (1/2 page)
- SwiftData query lifecycle: @Query → automatic UI updates → CloudKit sync
- Network flow: View → OpenRouterClient → NetworkManager → retry logic
- Cost tracking: ChatMessage → DailyCostLog → budget enforcement
- Security: API keys via KeychainManager (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)

### 4. Known Issues & Proposed Fixes (1/2 page)
**Issue 1: Model Import Runs Every Launch**
- Current: .task modifier in OpenrouterApp.swift runs import on every app launch
- Proposed Fix: Add UserDefaults flag "hasImportedModels", check before import
- Apple Reference: https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app

**Issue 2: AppState Not Integrated**
- Current: AppState.swift exists but not injected into SwiftUI environment
- Proposed Fix: Add .environmentObject(appState) in WindowGroup, use @EnvironmentObject in views
- Impact: Import progress tracking currently non-functional

**Issue 3: Silent Error Handling**
- Current: Errors printed to console, no user feedback
- Proposed Fix: Add @State var importError in ContentView, present .alert() on errors
- HIG Compliance: Users must see actionable error messages

### 5. Development Guidelines (1/4 page)
- Never store API keys in UserDefaults (use KeychainManager)
- SwiftData cascade deletes: ChatSession → ChatMessages
- Budget limits enforced at multiple layers (per-message, per-session, daily)
- CloudKit sync enabled (.automatic) - test offline scenarios
- Multi-platform: Build and test on iOS + macOS

### 6. Critical Configuration (1/4 page)
- Data source: /Users/denn/Kaggle/openrouter_models.json (345 models)
- Regional API endpoints: us-east, us-west, eu-west, ap-south, auto
- Subscription SKUs: com.openrouter.premium.monthly/yearly
- Deployment targets: iOS 26.2, macOS 26.2, visionOS 26.2

**Total: ~2.5 pages balanced guide**

## Phase 4: .gitignore Creation

**Entries to Add:**
```
# Xcode
build/
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/
*.xccheckout
*.moved-aside
DerivedData/
*.hmap
*.ipa
*.xcuserstate
*.xcscmblueprint

# Swift Package Manager
.swiftpm/
.build/

# CocoaPods
Pods/

# Carthage
Carthage/Build/

# fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

# macOS
.DS_Store

# SwiftData
*.sqlite
*.sqlite-shm
*.sqlite-wal

# API Keys & Secrets
*.env
secrets.json
api_keys.json

# IDE
.vscode/
.idea/
```

## Phase 5: Git Commit Strategy

**Staged Changes Review:**
- NetworkManager.swift - Production-ready with retry logic ✓
- OpenRouterClient.swift (partial) - Incomplete implementation ⚠️

**Unstaged Changes Review:**
- ContentView.swift - Complete tab navigation ✓
- OpenrouterApp.swift - SwiftData schema + CloudKit config ✓
- OpenRouterClient.swift (full) - Complete with chat & models endpoints ✓

**Recommended Commit Structure:**
1. Add .gitignore (separate commit)
2. Stage all current changes together as "Initial OpenRouter implementation"
3. Note: OpenRouterClient.swift has both staged (partial) and unstaged (complete) versions - use unstaged version

## Phase 6: Implementation Tasks

### Task 1: Create CLAUDE.md
**File:** /Users/denn/Desktop/Xcode/Openrouter/CLAUDE.md
**Content:** Balanced 2-3 page development guide (see Phase 3 structure)
**Action:** CREATE new file

### Task 2: Create .gitignore
**File:** /Users/denn/Desktop/Xcode/Openrouter/.gitignore
**Content:** Standard Swift/Xcode ignore patterns (see Phase 4)
**Action:** CREATE new file

### Task 3: Git Staging Cleanup (Per User Request)
**Action:** Use complete OpenRouterClient.swift version
**Steps:**
1. Unstage partial OpenRouterClient.swift (31 lines, staged)
2. Stage complete OpenRouterClient.swift (136 lines, unstaged)
3. Ensure all other changes are properly staged

**Files to Stage:**
- Openrouter/ContentView.swift (modified)
- Openrouter/OpenrouterApp.swift (modified)
- Openrouter/Services/NetworkManager.swift (new)
- Openrouter/Services/OpenRouterClient.swift (new - complete version)
- CLAUDE.md (new - to be created)
- .gitignore (new - to be created)

**Files Currently Untracked (should be staged):**
- Openrouter/AppState.swift (new)
- Openrouter/Models/AIModel.swift (new)
- Openrouter/Models/ChatMessage.swift (new)
- Openrouter/Models/ChatSession.swift (new)
- Openrouter/Models/DailyCostLog.swift (new)
- Openrouter/Models/ModelArchitecture.swift (new)
- Openrouter/Models/ModelParameters.swift (new)
- Openrouter/Models/ModelPricing.swift (new)
- Openrouter/Models/ModelProvider.swift (new)
- Openrouter/Models/OpenRouterModelDTO.swift (new)
- Openrouter/Models/UserPreferences.swift (new)
- Openrouter/Services/KeychainManager.swift (new)
- Openrouter/Services/ModelImportService.swift (new)
- Openrouter/Services/SubscriptionManager.swift (new)
- Openrouter/Views/ChatListView.swift (new)
- Openrouter/Views/ChatView.swift (new)
- Openrouter/Views/ModelBrowserView.swift (new)
- Openrouter/Views/ModelDetailView.swift (new)
- Openrouter/Views/ModelSelectorView.swift (new)
- Openrouter/Views/SettingsView.swift (new)
- Openrouter/Views/SubscriptionView.swift (new)
- Openrouter/Views/UsageTrackerView.swift (new)

**Files to Exclude from Staging:**
- build/ directory (will be gitignored)
- Openrouter/Item.swift (old template model, should be deleted)

### Task 4: Document Issues Only (Per User Request)
**Action:** Document known issues in CLAUDE.md with proposed fixes
**No code changes in this phase** - user selected "Document + Propose Fixes" option
**Issues to document:**
1. Model import runs every launch (propose UserDefaults fix)
2. AppState not integrated (propose @EnvironmentObject fix)
3. Silent error handling (propose @State alert fix)

## Phase 7: Verification Steps

### Build Verification
```bash
# iOS build
xcodebuild -scheme Openrouter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean build

# macOS build
xcodebuild -scheme Openrouter -destination 'platform=macOS' clean build

# Run tests
xcodebuild test -scheme Openrouter -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### SourceKit-LSP Configuration
```bash
# Generate compile commands for LSP
xcode-build-server config -scheme Openrouter -workspace Openrouter.xcodeproj

# Verify experimental mode support
xcode-build-server --help | grep experimental
```

### XCP Verification
```bash
# List all targets
xcp list-targets

# Verify groups structure
xcp list-groups
```

### Data Management Testing
1. Launch app fresh → verify models import once
2. Relaunch app → verify no duplicate import
3. Test error scenario → verify user sees alert
4. Check AppState in Xcode view debugger

### HIG Compliance Checks
- Tab bar icons use SF Symbols ✓
- Settings in dedicated tab ✓
- Navigation patterns follow platform conventions
- Error alerts use standard Alert modifiers
- Loading states use ProgressView

## Critical Files for Implementation

### Files to CREATE:
1. **/Users/denn/Desktop/Xcode/Openrouter/CLAUDE.md** - Balanced 2-3 page development guide
2. **/Users/denn/Desktop/Xcode/Openrouter/.gitignore** - Standard Swift/Xcode patterns

### Files to ADD to Git (currently untracked):
All Models (9 files):
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/AIModel.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/ChatMessage.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/ChatSession.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/DailyCostLog.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/ModelArchitecture.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/ModelParameters.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/ModelPricing.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/ModelProvider.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Models/OpenRouterModelDTO.swift

All Services (3 new files):
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Services/KeychainManager.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Services/ModelImportService.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Services/SubscriptionManager.swift

All Views (8 files):
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/ChatListView.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/ChatView.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/ModelBrowserView.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/ModelDetailView.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/ModelSelectorView.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/SettingsView.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/SubscriptionView.swift
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Views/UsageTrackerView.swift

App State:
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/AppState.swift

### Files Already MODIFIED (staged/unstaged):
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/ContentView.swift (unstaged)
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/OpenrouterApp.swift (unstaged)
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Services/NetworkManager.swift (staged)
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Services/OpenRouterClient.swift (BOTH staged partial + unstaged complete)

### File to DELETE:
- /Users/denn/Desktop/Xcode/Openrouter/Openrouter/Item.swift (old template model, no longer needed)

### Files to EXCLUDE (via .gitignore):
- build/ directory and all contents
- *.xcuserstate, xcuserdata/, DerivedData/
- .DS_Store files

## Implementation Checklist for Aider

### Step 1: Create Documentation Files
```bash
# Create CLAUDE.md (2-3 pages, balanced)
# Create .gitignore (Swift/Xcode standard)
```

### Step 2: Git Staging Cleanup
```bash
# Reset staging for OpenRouterClient.swift
git reset HEAD Openrouter/Services/OpenRouterClient.swift

# Stage complete version
git add Openrouter/Services/OpenRouterClient.swift

# Verify correct version is staged (should be 136 lines with chat & models endpoints)
git diff --cached Openrouter/Services/OpenRouterClient.swift | head -20
```

### Step 3: Add All New Files to Git
```bash
# Add all untracked files (21 total: 9 models + 3 services + 8 views + AppState)
git add Openrouter/AppState.swift
git add Openrouter/Models/*.swift
git add Openrouter/Services/KeychainManager.swift
git add Openrouter/Services/ModelImportService.swift
git add Openrouter/Services/SubscriptionManager.swift
git add Openrouter/Views/*.swift

# Add documentation files
git add CLAUDE.md .gitignore
```

### Step 4: Delete Obsolete Template File
```bash
# Remove old template model from Xcode project using xcp
xcp delete-file Openrouter/Item.swift

# Remove from git
git rm Openrouter/Item.swift
```

### Step 5: Verify All Changes
```bash
# Check git status - should show:
# - Modified: ContentView.swift, OpenrouterApp.swift
# - New: NetworkManager.swift, OpenRouterClient.swift (complete)
# - New: 9 Models, 3 Services, 8 Views, AppState.swift
# - New: CLAUDE.md, .gitignore
# - Deleted: Item.swift

git status
```

## Success Criteria

### Documentation
- [x] CLAUDE.md created (2-3 pages, balanced approach per user request)
- [x] Includes: Quick start commands, architecture overview, data flow, known issues with proposed fixes
- [x] Brief mention of xcp and xcode-build-server tools
- [x] Documents (but doesn't fix) the 3 known SwiftUI data management issues
- [x] .gitignore created with standard Swift/Xcode patterns

### Git Repository
- [x] OpenRouterClient.swift staging resolved (using complete 136-line version)
- [x] All 21 untracked files added to git
- [x] Item.swift template file removed
- [x] build/ directory excluded via .gitignore
- [x] Clean git status ready for commit

### Build Verification
- [ ] Project builds on iOS Simulator (iPhone 16 Pro, iOS 26.2)
- [ ] Project builds on macOS (26.2)
- [ ] No compiler errors or warnings
- [ ] SwiftData schema recognized (9 models)
- [ ] CloudKit configuration valid

### Apple Best Practices Alignment
- [x] Documented known issues with links to Apple docs
- [x] Keychain security patterns documented
- [x] SwiftData + CloudKit patterns documented
- [x] HIG compliance noted (tab navigation, settings placement)

## Notes for Implementation

**User Preferences (from questions):**
1. ✓ Balanced 2-3 page CLAUDE.md (not quick reference, not comprehensive manual)
2. ✓ Document + Propose Fixes (don't implement data management fixes now)
3. ✓ Use complete OpenRouterClient.swift version (unstaged 136 lines)
4. ✓ Brief mention only of xcp/xcode-build-server tools

**Critical Implementation Details:**
- The user wants to "pass plan to aidergoss" - ensure all file paths are absolute and complete
- User emphasized "make sure all files are added for aider" - comprehensive file list provided above
- OpenRouterClient.swift has two versions: staged (31 lines, incomplete) and unstaged (136 lines, complete) - MUST use complete version
- Item.swift is leftover from Xcode template, should be deleted via xcp tool
- Model import issue (runs every launch) is documented but NOT fixed per user request
- AppState integration issue is documented but NOT fixed per user request

**Apple Documentation References to Include in CLAUDE.md:**
- https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- SwiftData schema and CloudKit integration patterns
- Keychain Services best practices

**xcode-build-server Experimental Mode Note:**
- User mentioned "experimental mode on xcode-build-server sourcekit lsp"
- This likely refers to enabling experimental language server features
- Include brief note in CLAUDE.md about xcode-build-server config command
- Don't provide detailed experimental flags (brief mention only per user request)
