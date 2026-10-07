# Caelestia Shell: Changes and Architectural Decisions

This document provides a detailed record of all changes, bugs addressed, root causes identified, architectural decisions made, and files modified across the Caelestia QuickShell desktop environment.

---

## 1. Feature: Fullscreen Media Player

### Requirement
Create a fullscreen music player showing the current track, synchronized lyrics, cover art, spectrum visualizer, and playback controls. Follow the **DRY (Don't Repeat Yourself)** principle by reusing existing Caelestia components, styling, animations, and services rather than writing duplicate logic. The player must be toggled via a Quick Toggle button in the Utilities drawer (alongside Wi-Fi, DND, etc.) and via IPC / shortcuts.

### Root Causes / Challenges Addressed
* **Component Reusability**: Existing media components in `modules/dashboard/media/` were tightly coupled to the fixed dimensions and typography of the dashboard's right-side panel.
* **Wayland Layer Shell Integration**: A fullscreen window under Hyprland requires proper layer shell properties (`WlrLayershell.layer`, keyboard focus handling, input masking, and blur rules).

### Implementation Details & Decisions
1. **Per-Screen State Integration (`components/ScreenState.qml`)**:
   - Added `property bool fullscreenMedia`.
   - **Reason**: Caelestia tracks drawer and modal visibility on a per-monitor basis using `ScreenState`. Adding `fullscreenMedia` here ensures consistent multi-monitor behavior and integration with `ShellState`.

2. **Core Components (`modules/media/FullscreenMedia.qml` & `modules/media/Content.qml`)**:
   - Implemented as a `WlrLayershell` overlay on `WlrLayer.Overlay`.
   - Configured `WlrKeyboardFocus.OnDemand` when active, allowing the Escape key to close the player without grabbing keyboard focus when closed.
   - Uses an input region mask (`mask: shouldBeOpen ? null : emptyRegion`) to allow full click-through to desktop windows when closed.
   - Built with Caelestia design language:
     - Blurred, tinted album art background via `FadeImage` and `MultiEffect` (blurMax: 64).
     - Ambient drifting material shapes via reused `DashboardMedia.BackgroundShapes`.
     - Left column: Reused `DashboardMedia.CoverVisualiser` and `DashboardMedia.Details`.
     - Right column: Reused `DashboardMedia.LyricsAndSelector` for synchronized scrolling lyrics.
     - Fallback UI: Material shape (`ClamShell`) and active player switcher dropdown (`SplitButton`) when no media player is playing.

3. **Parametrization for Reusability (DRY)**:
   - **`modules/dashboard/media/CoverVisualiser.qml`**: Made `coverSize` a configurable property (`property real coverSize: Tokens.sizes.dashboard.coverSize`) so it scales up to 400px+ in fullscreen mode while keeping the exact same spectrum physics and canvas render loop.
   - **`modules/dashboard/media/Details.qml`**: Exposed `titleFont`, `artistFont`, `albumFont`, and `buttonScale` as configurable properties so typography matches the fullscreen scale without duplicating MPRIS logic.
   - **`modules/dashboard/media/LyricsAndSelector.qml`**: Forwarded `lyricFont` and `currentLyricFont` to `LyricList`.

4. **Hardware Blur & Hyprland Integration (`services/Colours.qml`)**:
   - Added layer rule `"blur, match:namespace quickshell:fullscreenMedia"` to Hyprland dynamic layer rules.
   - **Reason**: Ensures native GPU-accelerated blur behind the fullscreen overlay.

5. **Shell Loading & Shortcuts (`shell.qml` & `modules/Shortcuts.qml`)**:
   - Instantiated `FullscreenMedia` inside `shell.qml` per monitor screen.
   - Added `fullscreenMedia` custom shortcut and included it in the `drawers` IPC handler (`toggle`, `list`, `isOpen`).
   - CLI usage: `caelestia shell drawers toggle fullscreenMedia`.

---

## 2. Feature: No-Lyrics Fallback GIF

### Requirement
When a song does not have lyrics available, display the specified animated GIF instead of the plain sad icon placeholder:
`https://media.giphy.com/media/v1.Y2lkPWVjZjA1ZTQ3OWN3OWE5OHFtYXhndWhzbGtrYXo2c3YwYTYwYnRneHFxcm5xcW9uaSZlcD12MV9zdGlja2Vyc19zZWFyY2gmY3Q9cw/YIGRczuorjV2WK48Sa/giphy.gif`

### Root Cause / Challenge
* The default `noLyrics` state in `LyricList.qml` used a static `MaterialIcon` (`sentiment_sad`) and static text inside a `Loader`.
* Using a remote URL directly in QML can cause network latency, failed loading when offline, and playback stutter.

### Implementation Details & Decisions
1. **Local Asset Storage (`assets/no-lyrics.gif`)**:
   - Downloaded and stored the GIF locally in the shell repository assets directory.
   - Verified format: 480x480 GIF, ~349 KB.
2. **Animated Display (`modules/dashboard/media/LyricList.qml`)**:
   - Imported `Quickshell`.
   - Replaced the icon with `AnimatedImage`:
     ```qml
     AnimatedImage {
         Layout.alignment: Qt.AlignHCenter
         Layout.preferredWidth: Math.min(root.width * 0.8, 260)
         Layout.preferredHeight: Math.min(root.height * 0.5, 260)
         source: Quickshell.shellPath("assets/no-lyrics.gif")
         playing: Players.active?.isPlaying ?? true
         fillMode: AnimatedImage.PreserveAspectFit
         asynchronous: true
     }
     ```
   - Automatically synchronizes playback (`playing: Players.active?.isPlaying ?? true`).
   - Because `LyricList` is shared between the dashboard media tab and the new fullscreen player, both seamlessly benefit from this improvement.

---

## 3. Bug Fix: Audio Source Switcher Glitch / Instant Disappearance

### Symptoms
Clicking the audio status icon on the top bar opened the audio popout, but attempting to switch sinks or move the mouse into the popout caused it to instantly disappear.

### Root Causes Identified
1. **Premature Hover-Out in `Interactions.qml` (`inLeftPanel`)**:
   - `inLeftPanel` measured `panel.width` and `panel.y` during the popout's entrance animation (`offsetScale` transitioning from `1` to `0`).
   - When the cursor moved from the bar icon toward the popout while `offsetScale > 0`, the evaluated bounding box was smaller than the target geometry, failing the hit test and triggering `closeCurrentPopout()`.
2. **Initial Opening Position Jump in `ClipWrapper.qml`**:
   - `Behavior on y` in `ClipWrapper.qml` animated every position change. When opening a popout for the first time, `y` was animating from an old position (or `0`) to the target icon, causing the popout to slide across the screen and briefly exit the mouse path.
3. **Nonlinear Input Region Mask in `Regions.qml`**:
   - The input mask for `popoutsWrapper` used `Math.pow(1 - offsetScale, 2)`.
   - A quadratic curve meant that during the first half of the animation (`offsetScale = 0.5`), the clickable area was only 25% of its width. Mouse events fell through to the desktop.
4. **Dropdown Menu MouseArea Collision in `components/controls/Menu.qml`**:
   - The full-window modal `MouseArea` used by `Menu.qml` had `hoverEnabled: true`, intercepting hover events from `Interactions.qml` and resetting `hovered` state on the parent drawer.

### Changes Applied
* **`modules/drawers/Interactions.qml`**:
  - Implemented target bounding box evaluation for `panels.popoutsWrapper`: calculates `targetWidth`, `targetHeight`, and target clamped `targetY` so the cursor remains considered "inside" even while the entrance animation is running.
  - Added `openMenuCount` and `hasOpenMenu` guards: when a dropdown menu (`SplitButton`) is active, drawer and popout hover timeouts are suppressed.
* **`modules/bar/popouts/ClipWrapper.qml`**:
  - Added `enabled: root.offsetScale < 0.05` to `Behavior on y`. Snaps instantly to the target icon when opening and only animates smoothly when transitioning between icons while already open.
* **`modules/drawers/Regions.qml`**:
  - Changed input mask calculation to linear `content.nonAnimWidth * (1 - offsetScale)`.
* **`components/controls/Menu.qml`**:
  - Set `hoverEnabled: false` on the backdrop `MouseArea`.
  - Incremented / decremented `openMenuCount` on the parent window's `interactionWrapper`.

---

## 4. Bug Fix: Quick Toggle Animation Breakdown & Stutter

### Symptoms
When the `media` toggle was added to the Utilities drawer, the Quick Toggle row animations, button shape morphing (spring physics), and drawer interactions broke severely:
* Buttons in Row 2 clipped and failed to squeeze neighboring buttons when pressed.
* Row 1 and Row 2 had asymmetric button widths.
* Clicking the media toggle caused the entire drawer to rapidly flicker and jitter.

### Root Causes Identified
1. **C++ `ButtonRow` Spring Physics Disconnection**:
   - `ButtonRow.cpp` (`plugin/src/Caelestia/Components/buttonrow.cpp`) handles spring physics by querying `child->property("shapeMorphExpansion")` and connecting to `shapeMorphExpansionChanged()`.
   - The `nightLight` delegate in Row 2 had been wrapped inside a generic `Item` to support mouse-wheel temperature scrolling.
   - Because that wrapper `Item` lacked `property real shapeMorphExpansion`, `ButtonRow::getMorphExpansion(child)` returned `0.0` for `nightLight`.
   - When any neighboring button (`dnd`, `visualiser`, `media`) expanded, the layout math on Row 2 broke, causing layout jitter and clipping.
2. **Drawer Dismissal Hover Conflict in `Toggles.qml`**:
   - The `media` toggle's `onClicked` previously included:
     ```qml
     if (root.screenState.fullscreenMedia)
         root.screenState.utilities = false;
     ```
   - When the user clicked the toggle, their cursor was still inside the bottom-right corner.
   - Setting `screenState.utilities = false` started the drawer close animation, but on the very next frame, `Interactions.qml` detected the mouse via `inBottomPanel` and immediately set `screenState.utilities = true` back on, producing a rapid open/close loop.
3. **Asymmetric 5 vs. 4 Grid Split**:
   - 9 toggles split across 2 rows resulted in `splitIndex = 5` (5 items in Row 1, 4 items in Row 2), giving Row 2 buttons ~25% more base width than Row 1.

### Changes Applied
* **`modules/utilities/cards/Toggles.qml`**:
  - Added `property real shapeMorphExpansion: _toggle.shapeMorphExpansion` to the `nightLight` wrapper `Item` (binding directly to the inner `Toggle.shapeMorphExpansion`). Note: avoid `property alias` due to Qt 6.8+ `pragma ComponentBehavior: Bound` constraints on inline delegates.
  - Removed programmatic `screenState.utilities = false` from the `media` toggle `onClicked` handler. The fullscreen media overlay opens cleanly without triggering drawer close/re-open loops.
* **`modules/nexus/pages/panels/UtilitiesPanel.qml`**:
  - Registered `Media player` toggle under Utilities settings so users can enable/disable it in the Nexus GUI.

---

## Summary of Modified & Created Files

| File | Type | Purpose |
|---|---|---|
| `components/ScreenState.qml` | Modified | Added `property bool fullscreenMedia` |
| `shell.qml` | Modified | Instantiated `FullscreenMedia` overlay per monitor |
| `services/Colours.qml` | Modified | Added Hyprland blur rule for `quickshell:fullscreenMedia` |
| `modules/Shortcuts.qml` | Modified | Added `fullscreenMedia` shortcut & IPC handler |
| `modules/media/FullscreenMedia.qml` | **Created** | Layer shell wrapper, focus, and input masking |
| `modules/media/Content.qml` | **Created** | Fullscreen player UI layout reusing dashboard components |
| `modules/dashboard/media/CoverVisualiser.qml` | Modified | Added configurable `coverSize` property |
| `modules/dashboard/media/Details.qml` | Modified | Exposed font size and button scale properties |
| `modules/dashboard/media/LyricsAndSelector.qml` | Modified | Forwarded lyric typography properties to `LyricList` |
| `modules/dashboard/media/LyricList.qml` | Modified | Replaced sad icon with `no-lyrics.gif` via `AnimatedImage` |
| `assets/no-lyrics.gif` | **Created** | Downloaded local Giphy asset for no-lyrics fallback |
| `modules/bar/popouts/AudioPopout.qml` | Modified | Added fallback text for audio devices without description |
| `modules/bar/popouts/ClipWrapper.qml` | Modified | Prevented unclipped initial `y` slide animation on popouts |
| `modules/drawers/Interactions.qml` | Modified | Fixed target bounding box hover detection & menu tracking |
| `modules/drawers/Regions.qml` | Modified | Fixed popout input region mask to linear scaling |
| `components/controls/Menu.qml` | Modified | Disabled hover on menu backdrop; tracked `openMenuCount` |
| `modules/utilities/cards/Toggles.qml` | Modified | Added `media` toggle; fixed C++ morphing & drawer hover conflict |
| `modules/nexus/pages/panels/UtilitiesPanel.qml` | Modified | Added `Media player` toggle option to Nexus settings |

---

## 5. Bug Fix: Persistent Loading Spinner Overlapping Loaded Lyrics

### Symptoms
In both the dashboard media panel and the fullscreen media player, when lyrics loaded successfully, the cyan circle loading indicator ("Loading lyrics...") frequently persisted indefinitely on top of the lyrics. In the dashboard widget, the lyrics were active and clickable beneath the spinner; in fullscreen mode, the spinner visibly overlapped the text.

### Root Causes Identified
1. **Conflicting Animation Subsystems**:
   - `loadingIndicator` declared an explicit `Behavior on opacity { Anim { type: Anim.DefaultEffects } }`.
   - Concurrently, `LyricList.qml` used a QML State Machine with `transitions` containing `SequentialAnimation` that also animated `loadingIndicator.opacity`.
   - Qt Quick documentation warns that animating the same property with both a `Transition` and a `Behavior` causes race conditions, leaving properties stuck at intermediate or previous values (e.g., `opacity: 1.0`).
2. **Missing Visibility / Hit-Test Guards**:
   - `loadingIndicator`, `noLyrics`, and `lyrics` relied strictly on opacity without binding `visible: opacity > 0`.
   - Even when intended to be hidden or when opacity was stuck, elements remained in the scene graph receiving clicks and rendering over one another.
3. **C++ Signal Notification Mismatch (`lyrics.hpp` / `lyrics.cpp`)**:
   - `Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY lyricsChanged)` specifies `NOTIFY lyricsChanged`.
   - In `clearLines()`, C++ emitted `hasLyricsChanged()`, but not `lyricsChanged()`.
   - In `setLines()`, `emit lyricsChanged()` was called **before** `m_hasLyrics` was updated to `true`. When QML queried `hasLyrics`, it read stale `false`.
   - The original code attempted to work around this using a dummy `property bool flag` and `flag;` inside a JavaScript state binding, which frequently failed to re-evaluate when background candidate searches finished.

### Changes Applied
* **`modules/dashboard/media/LyricList.qml`**:
  - Eliminated the fragile `states: [...]`, `transitions: [...]`, and dummy `flag` binding hacks.
  - Implemented direct, mutually exclusive boolean states:
    ```qml
    property bool hasLyrics: Lyrics.hasLyrics && lyricList.length > 0
    readonly property bool isLoading: !hasLyrics && Lyrics.loading
    readonly property bool showNoLyrics: !hasLyrics && !isLoading
    ```
  - Added multi-signal synchronization via `Connections` (listening to both `onHasLyricsChanged` and `onLyricsChanged` with `Qt.callLater`) to guarantee that `hasLyrics` reflects true C++ state even if notification signals arrive out of order.
  - Bound opacities directly (`loadingIndicator.opacity: root.isLoading ? 1 : 0`, `lyrics.opacity: root.hasLyrics ? 1 : 0`, `noLyrics.opacity: root.showNoLyrics ? 1 : 0`).
  - Added strict `visible: opacity > 0` guards across all three components so inactive views cannot intercept input or visually overlap active views.

---

## 6. Redesign: Play Controls & Button Proportions

### Requirement
The play/pause button stretched horizontally across almost the entire width of the controls card in fullscreen mode (over 350px wide), creating an awkward, distorted bar that ruined the aesthetics of the media player. Redesign the playback controls to be compact, balanced, and aesthetically pleasing.

### Root Causes Identified
1. **Unbounded `fillWidth: true` in `ButtonRow`**:
   - In `modules/dashboard/media/Details.qml`, `ButtonRow` had `Layout.fillWidth: true`, and `playPauseBtn` was the sole child configured with `fillWidth: true`.
   - `ButtonRow.cpp` calculated `widthPerItem = (width() - totalSpacing - reservedWidth) / fillWidthCount`. In fullscreen mode with a 540px column width, `playPauseBtn` was forced to absorb all remaining width (~340px+), expanding into a giant white rectangle.
2. **Squircle Degradation on Active State**:
   - `playPauseBtn` had `checked: Players.active?.isPlaying ?? false`.
   - In `ButtonBase.qml`, `internalChecked = true` forced `radius: checkedRadius` (12px), overriding `isRound: true` and transforming the button from a smooth rounded shape into a sharp-cornered squircle.
3. **Full-Row Left-to-Right Stretch**:
   - `ButtonRow` lacked horizontal centering, anchoring controls from edge to edge instead of clustering them aesthetically beneath the track scrubber.

### Changes Applied
* **`modules/dashboard/media/Details.qml`**:
  - Removed `Layout.fillWidth: true` and `fillWidth: true` from `ButtonRow` and `playPauseBtn`.
  - Added `Layout.alignment: Qt.AlignHCenter` to `ButtonRow` to create a centered, harmonious control cluster directly beneath the progress bar.
  - Set `spacing: Math.max(Tokens.spacing.small, Math.round(Tokens.spacing.small * root.buttonScale))` for proportional spacing that scales with `buttonScale`.
  - Configured `playPauseBtn` with `implicitWidth: Math.round(implicitHeight * 1.25)` and removed `checked: ...`, keeping it as a compact, prominent Material pill (~60px wide) that morphs expressively via spring physics on click without stretching across the screen.
  - Sized `previousBtn` and `nextBtn` as perfect circles (`implicitWidth: implicitHeight`).
  - Standardized toggle buttons (`shuffle` and `repeat`) with `checkedRadius: Tokens.rounding.full` to preserve pill/circle rounding when active and avoid binding loops.

---

## 7. Bug Fix & Enhancement: Synchronized Lyrics Auto-Scrolling & Mid-View Centering

### Requirements
1. Lyrics do not scroll automatically as the track progresses.
2. The active lyric line must always be positioned vertically in the middle (`mid`) of the lyrics view.

### Root Causes Identified
1. **Destruction of `currentIndex` Dynamic Binding in `LyricList.qml`**:
   - `currentIndex` was initialized in `Component.onCompleted` using `currentIndex = Qt.binding(() => Lyrics.indexForTime(...))`.
   - In Qt Quick, any flick, mouse wheel scroll, or rebound on a `ListView` internally assigns to `currentIndex` from C++, which permanently overwrites and destroys the JavaScript dynamic binding. Once destroyed, `currentIndex` never updated as the song played.
2. **Missing MPRIS DBus Position Polling in `LyricList.qml`**:
   - Quickshell's `MprisPlayer` service does not emit streaming `positionChanged` signals continuously over DBus to avoid bus congestion.
   - Without an active polling timer in `LyricList.qml`, track position never updated if `Details.qml` was not concurrently ticking or when the fullscreen player was open.
3. **Ineffective Range Mode (`ListView.ApplyRange` vs. `ListView.StrictlyEnforceRange`)**:
   - `ApplyRange` only moves the view if an item crosses the viewport boundary; it does not reposition items toward the center.
   - `StrictlyEnforceRange` is required so that any change in `currentIndex` smoothly translates the entire view to keep the item strictly inside the highlight range.
4. **Viewport Boundary Clamping on First and Last Lyrics**:
   - In standard `ListView`, content bounds clamp `contentY >= 0`. Without vertical padding above line 0, the first lyric line was trapped at the very top of the container, unable to reach the vertical midpoint (`height / 2`).
   - Similarly, the last lyric line was trapped at the bottom edge because content could not scroll past `contentHeight - height`.
5. **Out-of-Sync Delegate Styling**:
   - Delegate highlight was bound to `ListView.isCurrentItem`. When the user scrolled the list, whichever line passed the center temporarily became `isCurrentItem`, lighting up the wrong line.

### Changes Applied
* **`modules/dashboard/media/LyricList.qml`**:
  - **Resilient State Binding**: Created a `readonly property int activeLyricIndex` on `root` evaluating `Lyrics.indexForTime(p.position)`. Because this property lives on the parent `Item`, it cannot be destroyed by `ListView` flicks.
  - **Continuous Position Polling**: Added a 250ms polling `Timer` calling `Players.active?.positionChanged()` while lyrics are loaded and the player is active.
  - **Strict Midpoint Enforcement**:
    - Changed `highlightRangeMode` to `ListView.StrictlyEnforceRange`.
    - Centered the highlight range dynamically:
      ```qml
      preferredHighlightBegin: height > 0 ? Math.round((height - (currentItem?.implicitHeight ?? currentItem?.height ?? 32)) / 2) : 0
      preferredHighlightEnd: height > 0 ? Math.round((height + (currentItem?.implicitHeight ?? currentItem?.height ?? 32)) / 2) : 0
      ```
    - Set `highlightMoveDuration: Tokens.anim.durations.large` with `highlightMoveVelocity: -1` for smooth fluid scrolling animations.
  - **Half-Viewport Buffer Headers and Footers**:
    - Added `header: Item { width: lyrics.width; height: Math.max(0, Math.round(lyrics.height / 2)) }` and `footer: Item { width: lyrics.width; height: Math.max(0, Math.round(lyrics.height / 2)) }`.
    - This provides half a screen of space above the first lyric and below the last lyric, enabling every line from index 0 to index N to be positioned precisely at the vertical midpoint (`height / 2`).
  - **Auto-Scroll Synchronization & Interactive Recovery**:
    - Added `syncToActiveLyric(smooth: bool)` to update `lyrics.currentIndex = target` (or call `positionViewAtIndex(target, ListView.Center)` for instant alignment).
    - When the user manually scrolls or flicks the list, auto-scrolling temporarily yields to allow reading. After 2.5 seconds of inactivity, it smoothly re-centers on the active lyric.
  - **Snappy Click-to-Seek**:
    - Clicking any lyric line immediately seeks the track, assigns `currentIndex`, and centers the clicked line at `ListView.Center` with zero delay.
  - **Independent Active Line Styling**:
    - Changed delegate styling to `readonly property bool isActive: index === root.activeLyricIndex`. The currently playing lyric maintains its primary color, larger font, and glow effects even during manual scrolling.


