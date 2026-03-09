# iOS Performance Analysis: Launch Time, Memory & Battery

**Role:** iOS performance engineer  
**Focus:** Reduce app launch time, minimize memory usage, lower battery consumption (bottlenecks, image loading, Swift optimizations).

---

## Step 1: Map app launch path and main-thread work

**What was done:**
- Traced entry point: `@main` → `VitalVuApp` → `ContentView()` → `BloodTestViewModel(context:)` → `loadTests()`.
- **Bottleneck identified:** `loadTests()` ran on the **main thread**: full Core Data fetch + parsing of all blood test entities before first frame. With many tests, this blocked the UI and increased Time to First Frame (TTF).

**Optimization applied:**
- **Move Core Data load off main thread:** `loadTests()` now uses `persistenceController.backgroundContext.perform { }` to fetch and parse on a background queue; results are applied on main via `DispatchQueue.main.async`. Launch no longer waits for the full load.
- **Limit initial fetch:** `fetchRequest.fetchLimit = 100` and `fetchRequest.fetchBatchSize = 50` so the first load is bounded (faster and lower memory). Load more on demand if you add pagination later.

**Files changed:** `VitalView/Models/BloodWorkModels.swift` — `loadTests()` rewritten to use background context and fetch limit.

---

## Step 2: Audit image loading (assets, PDFs)

**Findings:**
- **SF Symbols:** Used throughout; no custom image assets to optimize.
- **PDF OCR:** `PDFLabImporter.renderPageImage(page, dpi: 320)` produced very large bitmaps (e.g. 11" page at 320 DPI ≈ 3500×4500 px), causing high memory and CPU during PDF import.

**Optimizations applied:**
- **Lower default DPI:** 320 → 200 (`ocrRenderDPI = 200`) to reduce pixel count and OCR cost while keeping quality acceptable.
- **Cap render size:** `maxRenderDimension = 2048` so no single page render exceeds 2048 px on the longest side; scale is reduced when needed.
- **Autoreleasepool:** Wrap the render in `autoreleasepool { }` so the large bitmap is released as soon as the UIImage is returned, reducing peak memory during multi-page import.

**Files changed:** `VitalView/Models/PDFLabImporter.swift` — `renderPageImage` now uses capped DPI/dimensions and autoreleasepool.

---

## Step 3: Memory hotspots (Core Data, view models, caches)

**Findings:**
- **PersistenceController** and **BloodTestViewModel** each run a **30s Timer** for memory checks (duplicate work and extra wakeups).
- **BloodTestViewModel** already had batching and `maxTestsInMemory`; the main issue was the initial load blocking the main thread (fixed in Step 1).
- **NSPersistentHistoryTrackingKey** is enabled; if the app does not use CloudKit or persistent history, disabling it can reduce launch I/O and storage. Left enabled with a comment for you to toggle if needed.

**Optimizations applied:**
- **Single initial fetch limit:** Initial load now fetches at most 100 tests (see Step 1).
- **Memory timer interval:** Both timers increased from 30s to **60s** to reduce CPU wakeups and battery use while still catching memory growth.

**Files changed:**  
- `VitalView/Models/BloodWorkModels.swift` — fetch limit + 60s timer.  
- `VitalView/PersistenceController.swift` — 60s timer + comment on history tracking.

---

## Step 4: Battery / CPU drains

**Findings:**
- Two memory-monitoring timers (PersistenceController + BloodTestViewModel) firing every 30s.
- HealthKit prewarm runs in a `Task` on appear; acceptable.
- Splash stays ~2s; could be shortened if you want a snappier feel (optional).

**Optimizations applied:**
- Memory check interval set to **60s** in both places (see Step 3).
- No new recurring work added; Core Data and PDF work moved to background (Steps 1 and 2) so main thread and CPU are used less at launch and during import.

---

## Step 5: Additional Swift / UX cleanups

**Done:**
- **BloodDropView:** Removed `print(...)` in `onAppear` to avoid unnecessary log I/O and slight CPU in production.

**Files changed:** `VitalView/Views/BloodDropView.swift`.

---

## Summary of code changes

| Area              | Change                                                                 | Impact                          |
|-------------------|------------------------------------------------------------------------|---------------------------------|
| **Launch**        | `loadTests()` on background context + fetch limit 100                  | Shorter TTF, main thread free   |
| **Memory**        | Initial fetch limit; 60s memory timers                                | Lower peak memory, fewer wakes |
| **Image / PDF**   | PDF render DPI 200, max 2048 px, autoreleasepool                      | Less memory/CPU during import  |
| **Battery**       | 60s timers; heavy work off main thread                                | Fewer wakeups, less CPU         |
| **Misc**          | Removed debug print in BloodDropView; Core Data history comment      | Cleaner, documented option      |

---

## Optional next steps (not implemented)

1. **Persistent history:** If you do not use CloudKit or history APIs, set `NSPersistentHistoryTrackingKey` to `false` in `PersistenceController` to reduce store I/O at launch.
2. **Splash:** Reduce splash duration (e.g. to ~1.2s) and/or fade for a quicker “ready” feel.
3. **LazyView:** Current `LazyView` still builds content when the tab is shown. For true tab laziness, build content only when the tab is selected (e.g. via `TabView` selection + conditional content).
4. **Pagination:** If users have >100 tests, add “Load more” or pagination so the rest are loaded on demand instead of in one large fetch later.

---

## How to verify

- **Launch:** Measure Time to First Frame (e.g. Instruments “App Launch” or os_signpost) before/after; first frame should appear without waiting for Core Data load.
- **Memory:** Run Instruments Allocations during PDF import; peak memory should drop with the new render cap and autoreleasepool.
- **Battery:** Use Energy Log in Instruments; fewer 30s timers and less main-thread work should reduce CPU wakeups and energy use over time.
