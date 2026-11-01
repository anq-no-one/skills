# Apple docs and API map (iPhone Duo / iOS 27.1)

Fetch these when local Xcode search has no Duo hits. HTML and DocC JSON are the same article.

## Canonical pages

| What | HTML | DocC JSON |
|---|---|---|
| Hub | https://developer.apple.com/iphone-duo/ | — |
| Preparing your app | https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo | `…/technologyoverviews/preparing-your-app-for-iphone-duo.json` |
| HIG: Designing for iPhone Duo | https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo | `…/design/Human-Interface-Guidelines/designing-for-iphone-duo.json` |
| Xcode 27.1 beta notes | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes | `…/xcode-release-notes/xcode-27_1-release-notes.json` |
| Xcode 27.2 notes (points at 27.1 for Duo) | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes | `…/xcode-release-notes/xcode-27_2-release-notes.json` |
| Camera by direction | https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces | `…/avkit/choosing-a-camera-by-the-direction-it-faces.json` |
| Camera capture accessory | https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo | matching JSON under `/documentation/avfoundation/` |
| iPhone Mirroring (resize practice) | https://developer.apple.com/documentation/technotes/tn3210-optimizing-your-app-for-iphone-mirroring | — |
| Device Hub | https://developer.apple.com/documentation/xcode/device-hub | — |
| Automatic trait tracking | https://developer.apple.com/documentation/uikit/automatic-trait-tracking | — |

JSON base: `https://developer.apple.com/tutorials/data/documentation/` (HIG lives under `…/data/design/`).

## Tech Talks (Apple Developer)

| Talk | URL |
|---|---|
| Design for iPhone Duo | https://developer.apple.com/videos/play/tech-talks/111466 |
| Prepare your app for iPhone Duo | https://developer.apple.com/videos/play/tech-talks/111461 |
| Raise the bar with iPhone Duo | https://developer.apple.com/videos/play/tech-talks/111462 |
| Strike a pose with adaptive layouts | https://developer.apple.com/videos/play/tech-talks/111463 |
| Leverage multiple displays and scenes | https://developer.apple.com/videos/play/tech-talks/111464 |
| Build a great camera experience | https://developer.apple.com/videos/play/tech-talks/111465 |
| Make your UIKit app more flexible (WWDC25) | https://developer.apple.com/videos/play/wwdc2025/282 |
| Modernize your UIKit app (WWDC26) | https://developer.apple.com/videos/play/wwdc2026/278 |

## Hardware (from Apple's overview + HIG)

- Compact **outer** display (closed) and large **inner** display (open). Apple Newsroom: 5.4" outer / 7.6" inner, same aspect ratio.
- Outer front camera always occludes; inner front camera is under-display and occludes only while active.
- Outer camera region expands into Dynamic Island for Live Activities.
- Size classes (Prepare talk / HIG): outer ≈ compact width (other iPhones); inner ≈ regular width and regular height.
- Inner portrait keeps horizontal bars; closed outer and inner landscape move bars to the side.
- Split View 50/50 on the inner display is mandatory. A pinned PiP stack resizes the app vertically. New windows only on the **inner** display.

## SDK tiers (Preparing your app)

Rebuild with the latest Xcode to use all screen space. Builds from Xcode 26 and earlier do not extend under the status bar and camera.

UIScene lifecycle is already required for iOS 27 SDKs.

## SwiftUI ↔ UIKit

| Job | SwiftUI | UIKit / AV |
|---|---|---|
| Two-pane fold-aware layout | `ArrangementView` + `arrangementViewStyle` | `UIArrangementViewController` + `updateArrangement` |
| Split pane ratio / size | `splitArrangementLayoutRatio`, `splitArrangementFixedLayoutSize`, `splitArrangementLayoutSize` | `UISplitArrangement` dimension ranges |
| Overlay axis | `.overlay.axes(...)` | same arrangement value |
| Overlay z | `overlayArrangementZIndex` / `overlayArrangementEdge` | arrangement APIs on the controller |
| Fold / camera geometry | `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | `UIView.reservedRegions(kind:options:)` → `UIView.ReservedRegion` |
| Vertical bars opt-out | `toolbarVerticalBehavior` | `preferredVerticalBarBehavior` |
| Which edge | `toolbarVerticalEdge` | `verticalBarEdge` trait |
| Item axis | `axisBehavior` (`.automatic` / `.horizontalOnly` / `.verticalPreferred`) | `UIBarButtonItem.axisBehavior` |
| Overflow | `visibilityPriority`, `ToolbarOverflowMenu` | `visibilityPriority`, `additionalOverflowItems` |
| Bar vs tab compression | `toolbarVerticalCompressionBehavior` | `UINavigationItem.verticalBarCompressionBehavior` |
| Sheet placement | `presentationPlacement` | `UISheetPresentationController.preferredPlacement` |
| Hero under vertical bar | `backgroundExtensionEffect()` | `UIBackgroundExtensionView` |
| Hinge (effects, not layout) | `onHingeChange` → `DeviceHingeContext` / `DeviceHinge` | `UIHingeInteraction` / `UIHinge` (angle in radians; extra `.unknown`) |
| New window | existing scene APIs | `UIWindowScene.ActivationAction` (hides itself when windows are unavailable) |
| Camera direction | — | `AVCaptureDeviceDirectionCoordinator` (AVKit) |
| Physical front cameras | — | `.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera` |
| Outer-display capture UI | `sceneAccessory` + `CameraCaptureAccessory` | `UISceneAccessory.cameraCapture` + `registerSceneAccessory` |

`ArrangementView` is available on iOS, iPadOS, and Mac Catalyst. Apple recommends evaluating it on every supported device, not only Duo.

Default SwiftUI style is `.automatic` → split.

Horizontal-only split shows **only the primary** when the container is taller than it is wide — that is the intended compact collapse, not a bug.

## Reserved region kinds

- **Division** — folding region splits one view into smaller usable views. Active when partially open; inactive when fully open (width zero).
- **Occlusion** — hardware covers pixels (cameras).

Each region: frame, margins, kind, identifier, `isActive`. Re-query; do not cache a frame across poses.

Tech Talk vs symbol docs disagree on whether inactive regions return by default. Pass `.includeInactive` when you need them.

## Xcode 27.1 tooling (release notes)

Requires macOS Tahoe **26.6+**. Swift 6.4. SDKs include iOS 27.1.

- Previews canvas: **Display** group for the device's alternative display.
- Simulator: first launch can take several minutes.
- StandBy unavailable in the Duo runtime.
- Most app extensions cannot run or debug in the Duo runtime.
- Mac Catalyst: iOS 27.1-only APIs need `#if !targetEnvironment(macCatalyst)`.

App Resizability (renamed from the UIKit modernisation agent skill) supports SwiftUI and iPhone Duo in 27.1.

## What Apple tells you to prefer

- System containers: split views, tab bars, arrangement views, navigation stacks.
- Size class + scene/container bounds.
- Icons **and** titles on toolbar items that should survive vertical presentation.
- Navigation containers **around** arrangement views.

Layout off `userInterfaceIdiom` or `UIInterfaceOrientation` is the anti-pattern. `UIScreen.main` is ambiguous on two displays — use the window scene's screen if you need a `UIScreen` at all.
